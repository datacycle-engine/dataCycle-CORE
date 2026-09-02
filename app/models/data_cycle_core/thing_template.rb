# frozen_string_literal: true

module DataCycleCore
  class ThingTemplate < ApplicationRecord
    include ThingTemplateExtensions::PropertyTypes

    has_many :things, inverse_of: :thing_template, foreign_key: :template_name, primary_key: :template_name
    has_many :content_properties, inverse_of: :thing_template, foreign_key: :template_name, primary_key: :template_name, class_name: 'DataCycleCore::ContentProperties'

    # Templates are effectively static config, but Content#initialize looks one up on every
    # Thing.new. Cache the lookup by name to avoid a find_by per instantiation (imports build
    # thousands of transient Things). Invalidated on any write below; the bulk upsert_all in
    # MasterData::Templates::TemplateImporter skips callbacks and resets the caches explicitly.
    after_commit { DataCycleCore::ThingTemplate.reset_template_caches! }

    def self.cached_by_template_name(template_name)
      return if template_name.blank?

      # Only cache hits. Controllers pass raw user input as template_name into Thing.new (before
      # authorization), so caching misses would let arbitrary names accumulate nil entries forever
      # (unbounded until the next template write/reload). Real templates are a small, bounded set;
      # bogus names just re-run a cheap indexed find_by each time.
      cache = (@template_name_cache ||= Concurrent::Map.new)
      return cache[template_name] if cache.key?(template_name)

      find_by(template_name:).tap { |template| cache[template_name] = template if template }
    end

    # Values scanned out of every template schema: too expensive to expand for callers that ask per
    # saved content (DataCycleCore::Feature::LocaleInheritance, on every save that creates a locale),
    # so a scan is memoized for the process's life and never re-checked — re-checking cost a query
    # per save. Templates change only on an import, which replaces every process that could hold a
    # stale scan: in production the deploy shipping it restarts them, in development
    # MasterData::Templates::TemplateImporter touches this file, and both the Puma server and the jobs
    # container discard the class — and these ivars with it — once their watcher picks that up.
    def self.cached_schema_scan(key, &)
      (@schema_scan_cache ||= Concurrent::Map.new).compute_if_absent(key, &)
    end

    # Drops every process-level cache derived from the templates. They are read on hot paths and only
    # change when a template is written, so they share one invalidation point.
    def self.reset_template_caches!
      @template_name_cache = Concurrent::Map.new
      @schema_scan_cache = Concurrent::Map.new
      @classification_change_computed_properties = nil
    end

    scope :with_template_names, ->(template_names) { where(template_name: template_names) }
    scope :without_template_names, ->(template_names) { where.not(template_name: template_names) }
    scope :with_default_data_type, lambda { |classification_alias_names|
      template_types = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').where(internal_name: classification_alias_names).with_descendants.pluck(:internal_name)
      where("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_types)
    }

    scope :without_default_data_type, lambda { |classification_alias_names|
      template_types = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').where(internal_name: classification_alias_names).with_descendants.pluck(:internal_name)
      where.not("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_types)
    }

    scope :with_schema_type, lambda { |schema_type|
      where('thing_templates.api_schema_types && ARRAY[?]::VARCHAR[]', schema_type)
    }

    scope :without_schema_type, lambda { |schema_type|
      where.not('thing_templates.api_schema_types && ARRAY[?]::VARCHAR[]', schema_type)
    }

    scope :with_schema_classification_paths, lambda { |paths|
      schema_classifications = DataCycleCore::ClassificationAlias.by_full_paths(paths).with_descendants.pluck(:internal_name)
      where('thing_templates.api_schema_types && ARRAY[?]::VARCHAR[]', schema_classifications)
    }

    scope :without_schema_classification_paths, lambda { |paths|
      schema_classifications = DataCycleCore::ClassificationAlias.by_full_paths(paths).with_descendants.pluck(:internal_name)
      where.not('thing_templates.api_schema_types && ARRAY[?]::VARCHAR[]', schema_classifications)
    }

    scope :with_content_classification_paths, lambda { |paths|
      template_classifications = DataCycleCore::ClassificationAlias.by_full_paths(paths).with_descendants.pluck(:internal_name)
      where("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_classifications)
    }

    scope :without_content_classification_paths, lambda { |paths|
      template_classifications = DataCycleCore::ClassificationAlias.by_full_paths(paths).with_descendants.pluck(:internal_name)
      where.not("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_classifications)
    }

    scope :without_embedded, -> { where.not(content_type: 'embedded') }

    # {template_name => {computed_property_names:, tree_labels:, all_tree_labels:}} for computes flagged
    # with compute.recompute_on_classification_change. tree_labels gates which aliases trigger a
    # recompute, read from both spots the utilities take it from (override_or_mapped off the property,
    # parent_classification_name off :compute:).
    #
    # Every entry's gate can match: a compute no classification change can stale is dropped, one whose
    # tree cannot be derived gets all_tree_labels. An empty gate used to mean both — this ticket.
    #
    # Memoized: two matview scans, and the alias callback asks once per updated alias.
    def self.classification_change_computed_properties
      @classification_change_computed_properties ||= build_classification_change_computed_properties
    end

    # Single place the gate is applied, so all_tree_labels cannot be forgotten at one of the call sites.
    def self.classification_change_computed_properties_for(tree_label)
      return {} if tree_label.blank?

      classification_change_computed_properties.select { |_template_name, config| config[:all_tree_labels] || config[:tree_labels].include?(tree_label) }
    end

    def self.build_classification_change_computed_properties
      flagged = DataCycleCore::ContentProperties
        .where("property_definition -> 'compute' -> 'recompute_on_classification_change' = 'true'")
        .where("property_name NOT LIKE '%.%'")
        .pluck(
          :template_name,
          :property_name,
          Arel.sql("property_definition -> 'compute' -> 'parameters'"),
          Arel.sql("property_definition ->> 'tree_label'"),
          Arel.sql("property_definition -> 'compute' ->> 'tree_label'")
        )

      return {} if flagged.empty?

      # {[template, property] => tree_label}, nil where the parameter is universal. Keyed by the pair:
      # the query asks for every compute's parameter names at once, so a template-only key pulls in
      # same-named properties this compute never listed.
      classification_parameters = DataCycleCore::ContentProperties
        .where(template_name: flagged.map(&:first).uniq, property_name: flagged.flat_map { |f| parameter_names(f.third) }.uniq)
        .where("property_definition ->> 'tree_label' IS NOT NULL OR property_definition ->> 'type' = 'classification'")
        .pluck(:template_name, :property_name, Arel.sql("property_definition ->> 'tree_label'"))
        .to_h { |template_name, property_name, tree_label| [[template_name, property_name], tree_label] }

      # the gate is per template — a template's flagged properties are recomputed together
      flagged.group_by(&:first).each_with_object({}) do |(template_name, properties), registry|
        computed_property_names = properties.map(&:second)
        parameter_keys = properties.flat_map { |f| parameter_names(f.third) }.uniq
          .map { |property_name| [template_name, property_name] }
          .select { |key| classification_parameters.key?(key) }
        declared_tree_labels = properties.flat_map { |_t, _p, _parameters, tree_label, compute_tree_label| [tree_label, compute_tree_label] }

        tree_labels = (parameter_keys.map { |key| classification_parameters[key] } + declared_tree_labels).compact_blank.uniq
        # a declared tree wins, or every compute pairing one with a universal parameter widens to all
        all_tree_labels = tree_labels.blank? && parameter_keys.any? { |key| classification_parameters[key].blank? }

        next if tree_labels.blank? && !all_tree_labels

        # almost always a mistyped tree_label key, and costly enough to say so
        Rails.logger.warn("#{name}: #{template_name} #{computed_property_names.join(', ')} opted into recompute_on_classification_change without a derivable tree_label — recomputing on changes in every classification tree") if all_tree_labels

        registry[template_name] = { computed_property_names:, tree_labels:, all_tree_labels: }
      end
    end
    private_class_method :build_classification_change_computed_properties

    # compute parameters address nested properties as "property.path"
    def self.parameter_names(parameters)
      Array.wrap(parameters).map { |parameter| parameter.split('.').first }
    end
    private_class_method :parameter_names

    # distinct, sorted top-level computed property names across all templates
    # (nested properties are excluded as bulk recompute only operates on top-level keys)
    def self.computed_property_names
      DataCycleCore::ContentProperties
        .where("property_definition -> 'compute' IS NOT NULL")
        .where("property_name NOT LIKE '%.%'")
        .distinct
        .order(:property_name)
        .pluck(:property_name)
    end

    def readonly?
      true
    end

    # override initialize to setup template_name and thing_template correctly
    def initialize(attributes = nil)
      enriched_attributes = attributes&.to_h&.dup&.symbolize_keys || {}

      raise ActiveModel::MissingAttributeError, ":schema is required to initialize #{self.class.name}" if enriched_attributes&.dig(:schema).blank?

      enriched_attributes[:schema] = enriched_attributes[:schema].deep_dup.with_indifferent_access
      enriched_attributes[:template_name] ||= enriched_attributes[:schema][:name]

      super(enriched_attributes)
    end

    def property_definitions
      return @property_definitions if defined? @property_definitions

      @property_definitions = schema&.[]('properties') || {}
    end

    def schema_sorted
      sorted_properties = schema['properties'].map { |key, value| { key => value } }.sort_by { |i| i.values.first['sorting'] }.inject(&:merge)
      schema.deep_dup.merge({ 'properties' => sorted_properties })
    end

    def property_names
      property_definitions.keys
    end
    alias properties property_names

    def template_thing
      @template_thing ||= begin
        tt = DataCycleCore::Thing.new(thing_template: self)
        tt.readonly!
        tt
      end
    end

    def all_templates
      return @all_templates if defined? @all_templates

      @all_templates = self.class.all.index_by(&:template_name)
      thing_counts = DataCycleCore::Thing.where(template_name: @all_templates.keys)
        .group(:template_name).count.to_h

      @all_templates.each_value do |v|
        v.instance_variable_set(:@thing_count, thing_counts[v.template_name].to_i)
        v.instance_variable_set(:@all_templates, @all_templates)
      end

      @all_templates
    end

    def schema_as_json(visited = Set.new)
      visited += [template_name]
      content = schema_sorted

      template_thing.property_names.each do |property_name|
        content['properties'][property_name]['api_name'] = template_thing.api_name_for(property_name)
      end

      template_thing.embedded_property_names.each do |property_name|
        content['properties'][property_name]['embedded_schema'] = Array.wrap(content.dig('properties', property_name, 'template_name')).map do |et|
          if visited.include?(et)
            { 'name' => et, 'recursive' => true }
          else
            all_templates[et].schema_as_json(visited)
          end
        end
      end

      content['api_schema_types'] = api_schema_types
      content['template_paths'] = template_paths
      content['thing_count'] = thing_count

      content
    end

    def thing_count
      return @thing_count if defined? @thing_count

      @thing_count = things.count
    end

    def self.schema_as_json
      all_templates = first.all_templates

      all.map do |tt|
        all_templates[tt.template_name].schema_as_json
      end
    end

    def schema_types
      schema_ancestors.map do |ancestors|
        ancestors.push("dcls:#{template_name}") if ancestors.last != template_name
        ancestors
      end
    end

    def schema_ancestors
      Array.wrap(schema&.[]('schema_ancestors')).deep_dup.then { |a| a.present? && !a.all?(::Array) ? [a] : a }
    end

    def self.template_things
      all.map(&:template_thing)
    end

    def self.things
      DataCycleCore::Thing.where(template_name: pluck(:template_name))
    end

    def self.translated_property_labels(locale:, attributes:, count: nil, specific: nil)
      return {} if attributes.blank?

      keys = attributes.is_a?(::Hash) ? attributes.keys : attributes
      cps = DataCycleCore::ContentProperties
        .includes(:thing_template)
        .where(property_name: keys)
        .group_by(&:property_name)
        .filter_map do |key, cps|
        label = cps.filter_map { |cp|
          next unless attributes.is_a?(::Array) || attributes[cp.property_name]&.include?(cp.template_name)

          DataCycleCore::Thing.human_attribute_name(cp.property_name, {
            base: cp.thing_template.template_thing,
            locale:,
            definition: cp.property_definition,
            locale_string: false,
            count:,
            specific:
          })
        }.uniq.join(' / ')

        next if label.blank?

        [label, key]
      end

      cps.sort!
      cps
    end

    def self.translated_property_names(locale:)
      template_things
        .to_h do |t|
          [
            t.template_name,
            t.property_names.index_with do |k|
              definition = t.properties_for(k)
              {
                text: t.class.human_attribute_name(k, { base: t, locale:, definition:, locale_string: false }),
                type: definition['type'],
                template: definition['type'] == 'embedded' ? definition['template_name'] : nil,
                embedded_template: t.embedded?
              }
            end
          ]
        end
    end
  end
end
