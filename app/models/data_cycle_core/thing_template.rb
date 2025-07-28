# frozen_string_literal: true

module DataCycleCore
  class ThingTemplate < ApplicationRecord
    has_many :things, inverse_of: :thing_template, foreign_key: :template_name, primary_key: :template_name

    scope :with_template_names, ->(template_names) { where(template_name: template_names) }
    scope :without_template_names, ->(template_names) { where.not(template_name: template_names) }
    scope :with_default_data_type, lambda { |classification_alias_names|
      template_types = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').where(internal_name: classification_alias_names).with_descendants.pluck(:internal_name)

      where("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_types)
    }
    scope :with_schema_type, lambda { |schema_type|
      where('thing_templates.api_schema_types && ARRAY[?]::VARCHAR[]', schema_type)
    }

    scope :without_default_data_type, lambda { |classification_alias_names|
      template_types = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').where(internal_name: classification_alias_names).with_descendants.pluck(:internal_name)
      where.not("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_types)
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

    delegate :properties_for, to: :template_thing

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
      schema&.[]('properties') || {}
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

    def schema_as_json
      content = schema_sorted
      embedded = template_thing.embedded_property_names

      embedded.each do |property_name|
        content['properties'][property_name]['embedded_schema'] = Array.wrap(content.dig('properties', property_name, 'template_name')).map do |et|
          all_templates[et].schema_as_json
        end
      end

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

      DataCycleCore::ContentProperties.includes(:thing_template).where(property_name: keys).group_by(&:property_name)
        .to_h do |key, cps|
        [
          key,
          cps.filter_map { |cp|
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
        ]
      end
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
