# frozen_string_literal: true

raise 'ActiveRecord::Relation#load_records is no longer available, check patch!' unless ActiveRecord::Relation.method_defined? :load_records
raise 'ActiveRecord::Relation#load_records arity != 1, check patch!' unless ActiveRecord::Relation.instance_method(:load_records).arity == 1

module DataCycleCore
  module Content
    class Content < ApplicationRecord
      NESTED_STORAGE_LOCATIONS = ['metadata', 'content'].freeze
      # TODO: remove after final refactor_data_definition migration
      NEW_STORAGE_LOCATION = {
        'value' => 'metadata',
        'translated_value' => 'content',
        'column' => 'column',
        'classification' => 'classification'
      }.freeze
      WEBHOOK_ACCESSORS = [:webhook_as_of].freeze
      STRING_PROPERTY_TYPES = ['string'].freeze
      PLAIN_PROPERTY_TYPES = ['key', *STRING_PROPERTY_TYPES, 'number', 'date', 'datetime', 'boolean', 'slug'].freeze
      LINKED_PROPERTY_TYPES = ['linked'].freeze
      EMBEDDED_PROPERTY_TYPES = ['embedded'].freeze
      CLASSIFICATION_PROPERTY_TYPES = ['classification'].freeze
      SCHEDULE_PROPERTY_TYPES = ['schedule', 'opening_time'].freeze
      OPENING_TIME_PROPERTY_TYPES = ['opening_time'].freeze
      TIMESERIES_PROPERTY_TYPES = ['timeseries'].freeze
      ASSET_PROPERTY_TYPES = ['asset'].freeze
      COLLECTION_PROPERTY_TYPES = ['collection'].freeze
      TABLE_PROPERTY_TYPES = ['table'].freeze
      OEMBED_PROPERTY_TYPES = ['oembed'].freeze
      SIMPLE_OBJECT_PROPERTY_TYPES = ['object'].freeze
      GEO_PROPERTY_TYPES = ['geographic'].freeze
      SLUG_PROPERTY_TYPES = ['slug'].freeze
      ATTR_ACCESSORS = [:datahash, :datahash_changes, :previous_datahash_changes, :original_id, :duplicate_id, :local_import, :webhook_run_at, :webhook_priority, :prevent_webhooks, :synchronous_webhooks, :allowed_webhooks, :webhook_source, *WEBHOOK_ACCESSORS].freeze
      ATTR_WRITERS = [:webhook_data].freeze
      INTERNAL_PROPERTY_NAMES = ['id', 'external_source_id', 'external_key', 'schema_types', 'data_type'].freeze

      after_update :update_template_defaults, if: :template_name_previously_changed?

      self.abstract_class = true

      enum :aggregate_type, { default: 'default', aggregate: 'aggregate', belongs_to_aggregate: 'belongs_to_aggregate' }, prefix: :aggregate_type

      attr_accessor(*ATTR_ACCESSORS)
      attr_writer(*ATTR_WRITERS)

      extend  Common::ArelBuilder
      extend  Searchable
      include DestroyContent
      include DataHashUtility
      include Extensions::Content
      include Extensions::ContentWarnings
      include Extensions::Api
      include Extensions::SyncApi
      include Extensions::Geojson
      include Extensions::Mvt
      include Extensions::DefaultValue
      include Extensions::ComputedValue
      include Extensions::PropertyPreloader
      include Extensions::Translation
      include Extensions::Geo
      include Extensions::Thing
      include Extensions::Slug
      include Extensions::ConceptTransformations
      include Extensions::LinkedInText

      DataCycleCore.features.each_key do |key|
        feature = DataCycleCore::Feature[key]
        include feature.content_module if feature&.enabled? && feature.content_module
      end

      scope :where_value, ->(attributes) { where(value_condition(attributes), *attributes&.values) }
      scope :where_not_value, ->(attributes) { where.not(value_condition(attributes), *attributes&.values) }

      scope :where_translated_value, ->(attributes) { includes(:translations).where(translated_value_condition(attributes), *attributes&.values).references(attributes.blank? ? nil : :translations) }
      scope :where_not_translated_value, ->(attributes) { includes(:translations).where.not(translated_value_condition(attributes), *attributes&.values).references(attributes.blank? ? nil : :translations) }

      after_save :move_changes_to_previous_changes, :reload_memoized
      # after_find :initialize_template_properties

      # override initialize to setup template_name and thing_template correctly
      def initialize(attributes = nil)
        attrs = attributes&.to_h&.symbolize_keys || {}
        template_attrs = attrs.slice(:template_name, :thing_template)
        normal_attrs = attrs.except(:template_name, :thing_template)

        template_attrs[:thing_template] ||= DataCycleCore::ThingTemplate.find_by(template_name: template_attrs[:template_name]) if template_attrs[:template_name].present?
        template_attrs[:template_name] ||= template_attrs[:thing_template].template_name if template_attrs[:thing_template].present?

        super(template_attrs) do
          validate_template!
          normal_attrs[:boost] ||= thing_template.schema&.dig('boost').to_i
          normal_attrs[:content_type] ||= thing_template.schema&.dig('content_type')
          normal_attrs[:aggregate_type] = 'aggregate' if !normal_attrs.key?(:aggregate_type) && DataCycleCore::Feature::Aggregate.aggregate?(self)
          assign_attributes(normal_attrs)

          yield self if block_given?
        end
      end

      def self.value_condition(attributes)
        attributes&.map { |k, v| "things.metadata ->> '#{k}' #{v.is_a?(::Array) ? 'IN (?)' : '= ?'}" }&.join(' AND ')
      end

      def self.translated_value_condition(attributes)
        attributes&.map { |k, v| "thing_translations.content ->> '#{k}' #{v.is_a?(::Array) ? 'IN (?)' : '= ?'}" }&.join(' AND ')
      end

      def attr_accessor_attributes
        ATTR_ACCESSORS.index_with { |k| send(k) }.stringify_keys
      end

      def reload(options = nil)
        reload_memoized

        super
      end

      def generic_template?
        template_name == 'Generic'
      end

      def webhook_data
        return @webhook_data if defined? @webhook_data

        @webhook_data = OpenStruct.new
      end

      def method_missing(name, *args, &)
        original_name = name.to_s
        root_name = name.to_s.delete_suffix('=').delete_suffix("_#{overlay_name}")
        property_definition = properties_for(root_name)

        if property_definition && name.to_s.ends_with?('=')
          raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1)" unless args.size == 1
          set_property_value(name.to_s.delete_suffix('='), property_definition, args.first)
        elsif property_definition
          overlay_flag = original_name.ends_with?(overlay_name)
          original_name = original_name.delete_suffix("_#{overlay_name}") if DataCycleCore::Feature::Overlay.enabled? && original_name.ends_with?(overlay_name)

          if original_name.in?(embedded_property_names) || original_name.in?(linked_property_names)
            raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1)" if args.size > 1
            get_property_value(original_name, property_definition, args.first, overlay_flag && original_name.in?(overlay_property_names))
          else
            raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" if args.size.positive?
            get_property_value(original_name, property_definition, nil, overlay_flag && original_name.in?(overlay_property_names))
          end
        else
          super
        end
      end

      def respond_to?(method_name, include_all = false)
        root_name = method_name.to_s.delete_suffix('=').delete_suffix("_#{overlay_name}")

        property_names.include?(root_name) || super
      rescue StandardError
        super
      end

      def property?(property_name)
        property_definitions.key?(property_name.to_s)
      end

      def errors
        @errors ||= ActiveSupport::HashWithIndifferentAccess.new do |h, key|
          h[key] = ActiveModel::Errors.new(self)
        end

        @errors[I18n.locale]
      end

      def i18n_errors
        @errors || ActiveSupport::HashWithIndifferentAccess.new
      end

      def warnings
        @warnings ||= ActiveSupport::HashWithIndifferentAccess.new do |h, key|
          h[key] = ActiveModel::Errors.new(self)
        end

        @warnings[I18n.locale]
      end

      def i18n_warnings
        @warnings || ActiveSupport::HashWithIndifferentAccess.new
      end

      def valid?(*_args)
        errors.blank?
      end

      def i18n_valid?
        i18n_errors&.none? { |(_k, v)| v.present? }
      end

      def content_template
        return @content_template if defined? @content_template
        @content_template = DataCycleCore::Thing.new(thing_template:)
      end

      def content_type?(*types)
        types&.flatten&.map(&:to_s)&.include?(content_type)
      end

      def container?
        content_type == 'container'
      end

      def embedded?
        content_type == 'embedded'
      end

      def synch?
        external_system_syncs.present?
      end

      def external?
        external_source_id.present?
      end

      def schema_type
        api_schema_types&.first || schema&.dig('schema_type')
      end

      def schema_ancestors
        Array.wrap(schema&.dig('schema_ancestors')).deep_dup.then { |a| a.present? && !a.all?(::Array) ? [a] : a }
      end

      def translatable?
        schema&.dig('features', 'translatable', 'allowed') || false
      end

      def creatable?(scope)
        schema['content_type'] != 'embedded' &&
          schema.dig('features', 'creatable', 'allowed') &&
          (
          schema.dig('features', 'creatable', 'scope').blank? ||
            schema.dig('features', 'creatable', 'scope')&.include?(scope)
        )
      end

      def property_definitions
        thing_template&.property_definitions || {}
      end

      def property_names
        property_definitions.keys
      end
      alias properties property_names
      alias property_names_with_overlay property_names

      def properties_for(property_name, include_overlay = false)
        return if property_name.blank?
        include_overlay ? property_definitions.merge(add_overlay_property_definitions)[property_name.to_s] : property_definitions[property_name.to_s]
      end

      def writable_property_names
        property_names - virtual_property_names
      end

      def overlay_property_names_for(property_name, include_overlay = false)
        name_property_selector(include_overlay) do |definition|
          definition.dig('features', 'overlay', 'overlay_for') == property_name
        end
      end

      def aggregate_property_names_for(property_name, include_overlay = false)
        name_property_selector(include_overlay) do |definition|
          definition.dig('features', 'aggregate', 'aggregate_for') == property_name
        end
      end

      def translatable_property_names
        return @translatable_property_names if defined? @translatable_property_names

        @translatable_property_names = property_definitions.select { |property_name, definition|
          translatable_property?(property_name, definition)
        }.keys
      end

      def required_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition.dig('validations', 'required') }
      end

      def translated_columns
        @translated_columns ||= "#{self.class}::Translation".constantize.column_names
      end

      def translatable_string_property_names
        name_property_selector { |definition| STRING_PROPERTY_TYPES.include?(definition['type']) }
          .intersection(translatable_property_names)
      end

      def untranslatable_string_property_names
        name_property_selector { |definition| STRING_PROPERTY_TYPES.include?(definition['type']) }
          .intersection(untranslatable_property_names)
      end

      def translatable_property?(property_name, property_definition = nil)
        property_definition ||= properties_for(property_name)

        property_definition&.dig('storage_location') == 'translated_value' ||
          (property_definition&.dig('storage_location') == 'column' && translated_columns.include?(property_name)) ||
          (EMBEDDED_PROPERTY_TYPES.include?(property_definition&.dig('type')) && !property_definition&.dig('translated'))
      end

      def untranslatable_property_names
        return @untranslatable_property_names if defined? @untranslatable_property_names

        @untranslatable_property_names = property_names - translatable_property_names
      end

      def combined_property_names(api_version = nil)
        property_definitions.select { |_, definition|
          if api_version.present? && definition.dig('api', api_version).present?
            definition.dig('api', api_version, 'transformation', 'method') == 'combine'
          else
            definition.dig('api', 'transformation', 'method') == 'combine'
          end
        }.sort_by { |_k, v| v['sorting'] }.to_h.keys
      end

      def attribute_transformation_mapping(api_version = nil)
        # find transformation method: unwrap
        property_definitions.select { |_, definition|
          if api_version.present? && definition.dig('api', api_version).present?
            definition.dig('api', api_version, 'transformation', 'method') == 'unwrap'
          else
            definition.dig('api', 'transformation', 'method') == 'unwrap'
          end
        }.to_h do |k, v|
          [k, v['properties'].keys.map { |prop_key| prop_key.camelize(:lower) }]
        end
      end

      def plain_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| PLAIN_PROPERTY_TYPES.include?(definition['type']) }
      end

      def slug_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| SLUG_PROPERTY_TYPES.include?(definition['type']) }
      end

      def virtual_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition.key?('virtual') }
      end

      def table_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| TABLE_PROPERTY_TYPES.include?(definition['type']) }
      end

      def oembed_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| OEMBED_PROPERTY_TYPES.include?(definition['type']) }
      end

      def linked_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| LINKED_PROPERTY_TYPES.include?(definition['type']) }
      end

      def inverse_linked_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| LINKED_PROPERTY_TYPES.include?(definition['type']) && definition['link_direction'] == 'inverse' }
      end

      def collection_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| COLLECTION_PROPERTY_TYPES.include?(definition['type']) }
      end

      def embedded_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| EMBEDDED_PROPERTY_TYPES.include?(definition['type']) }
      end

      def included_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| SIMPLE_OBJECT_PROPERTY_TYPES.include?(definition['type']) }
      end

      def computed_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition.key?('compute') }
      end

      def computed_without_fallback_property_names
        name_property_selector do |definition|
          definition.key?('compute') && !definition.dig('compute', 'fallback')
        end
      end

      def text_with_linked_property_names(include_overlay = false)
        name_property_selector(include_overlay) do |definition|
          definition['type'] == 'string' &&
            definition.dig('ui', 'edit', 'type') == 'text_editor' &&
            definition.dig('ui', 'edit', 'options', 'data-size') == 'full'
        end
      end

      def resolved_computed_dependencies(key, datahash = {})
        if computed_property_names.include?(key) && !datahash&.key?(key)
          Array.wrap(properties_for(key)&.dig('compute', 'parameters')).map { |p|
            resolved_computed_dependencies(p.split('.').first, datahash)
          }.flatten.uniq
        else
          [key]
        end
      end

      def dependent_computed_property_names(keys)
        property_definitions.select { |_, definition|
          Array.wrap(definition.dig('compute', 'parameters'))
            .map { |p| p.split('.').first }
            .intersect?(Array.wrap(keys))
        }.keys
      end

      def default_value_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition.key?('default_value') }
      end

      def classification_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| CLASSIFICATION_PROPERTY_TYPES.include?(definition['type']) }
      end

      def classification_properties(include_overlay = false)
        property_selector(include_overlay) { |definition| CLASSIFICATION_PROPERTY_TYPES.include?(definition['type']) }
      end

      def asset_property_names
        name_property_selector { |definition| ASSET_PROPERTY_TYPES.include?(definition['type']) }
      end

      def schedule_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| SCHEDULE_PROPERTY_TYPES.include?(definition['type']) }
      end

      def opening_time_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| OPENING_TIME_PROPERTY_TYPES.include?(definition['type']) }
      end

      def timeseries_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| TIMESERIES_PROPERTY_TYPES.include?(definition['type']) }
      end

      def external_property_names
        name_property_selector { |definition| definition['external'] }
      end

      def relation_property_names(include_overlay = false)
        linked_property_names(include_overlay) +
          embedded_property_names(include_overlay) +
          classification_property_names(include_overlay) +
          asset_property_names +
          schedule_property_names(include_overlay)
      end

      def untranslatable_embedded_property_names
        name_property_selector { |definition| EMBEDDED_PROPERTY_TYPES.include?(definition['type']) && definition['translated'] }
      end

      def searchable_embedded_property_names
        property_definitions.select { |_, definition|
          EMBEDDED_PROPERTY_TYPES.include?(definition['type']) && definition['advanced_search'] == true
        }.keys
      end

      def advanced_search_property_names
        name_property_selector { |definition| ['embedded', 'object', 'linked', 'classification'].exclude?(definition['type']) && definition['advanced_search'] == true }
      end

      def advanced_included_search_property_names
        property_definitions.select { |_, definition|
          SIMPLE_OBJECT_PROPERTY_TYPES.include?(definition['type']) && definition['advanced_search'] == true
        }.keys
      end

      def advanced_classification_property_names
        name_property_selector { |definition| definition['type'] == 'classification' && definition['advanced_search'] == true }
      end

      def geo_properties(include_overlay = false)
        property_selector(include_overlay) { |definition| GEO_PROPERTY_TYPES.include?(definition['type']) }
      end

      def geo_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| GEO_PROPERTY_TYPES.include?(definition['type']) }
      end

      def global_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['global'] == true }
      end

      def local_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['local'] == true }
      end

      def search_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['search'] == true }
      end

      def new_overlay_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition.dig('features', 'overlay', 'allowed') }
      end

      def title_property_name
        name_property_selector { |definition| definition['type'] == 'string' && definition.dig('ui', 'is_title') == true }.first || 'name'
      end

      def exif_property_names
        name_property_selector { |definition| definition['exif'].present? }
      end

      def resettable_import_property_names
        writable_property_names - local_property_names - global_property_names - INTERNAL_PROPERTY_NAMES - computed_without_fallback_property_names
      end

      # returns data the same way, as .as_json
      def to_h
        Array.wrap(property_names)
          .difference(virtual_property_names)
          .index_with { |k| attribute_to_h(k) }
          .deep_stringify_keys
      end

      # returns data the same way, as .as_json
      def to_h_partial(partial_properties)
        Array.wrap(partial_properties)
          .intersection(property_names_with_overlay)
          .index_with { |k| attribute_to_h(k) }
          .deep_stringify_keys
      end

      # returns data the same way, as .as_json
      def attribute_to_h(property_name)
        root_name = property_name.delete_suffix("_#{overlay_name}")

        if property_name == 'id' && history?
          send(self.class.to_s.split('::')[1].foreign_key) # for history records original_key is saved in "content"_id
        elsif plain_property_names.include?(root_name) ||
              table_property_names.include?(root_name) ||
              oembed_property_names.include?(root_name) ||
              geo_property_names.include?(root_name)
          send(property_name)&.as_json
        elsif classification_property_names.include?(root_name) ||
              linked_property_names.include?(root_name) ||
              collection_property_names.include?(root_name)
          send(property_name).try(:pluck, :id)
        elsif included_property_names.include?(root_name)
          embedded_hash = send(property_name).to_h
          embedded_hash.presence
        elsif embedded_property_names.include?(root_name)
          embedded_array = send(property_name)
          embedded_array = embedded_array.map(&:get_data_hash) if embedded_array.present?
          embedded_array.blank? ? [] : embedded_array.compact
        elsif asset_property_names.include?(root_name)
          send(property_name)&.id
        elsif schedule_property_names.include?(root_name)
          schedule_array = send(property_name)
          schedule_array = schedule_array.map(&:to_h).presence
          schedule_array.blank? ? [] : schedule_array.compact
        elsif timeseries_property_names.include?(root_name)
          [] # don't load all timeseries from db
        else
          raise StandardError, "cannot determine how to serialize #{property_name}"
        end
      end

      def verify
        inconsistent_properties = translatable_property_names & untranslatable_property_names
        raise StandardError, "cannot determine whether some properties (#{inconsistent_properties.join(',')}) are translatable or not" unless inconsistent_properties.empty?
        self
      end

      def history?
        is_a?(DataCycleCore::Thing::History)
      end

      def collect_properties(definition = schema, parents = [])
        parents = Array.wrap(parents)
        key_paths = []
        definition&.dig('properties')&.each do |k, v|
          key_paths << (parents + [k])
          key_paths << collect_properties(v, parents + [k, 'properties']) if v&.key?('properties')
        end
        key_paths.flatten(1)
      end

      def enabled_features
        @enabled_features ||= DataCycleCore::FeatureService.enabled_features(schema)
      end

      def get_property_value(property_name, property_definition, filter = nil, overlay_flag = false)
        key = attibute_cache_key(property_name, filter, overlay_flag)

        # disable preloader
        # preload_property(property_name, filter, overlay_flag) unless history?

        return @get_property_value[key] if @get_property_value&.key?(key)

        (@get_property_value ||= {})[key] =
          if virtual_property_names.include?(property_name)
            load_virtual_attribute(property_name, I18n.locale)
          elsif plain_property_names.include?(property_name) || table_property_names.include?(property_name) || oembed_property_names.include?(property_name)
            load_json_attribute(property_name, property_definition, overlay_flag)
          elsif included_property_names.include?(property_name)
            load_included_data(property_name, property_definition, overlay_flag)
          elsif classification_property_names.include?(property_name)
            load_classifications(property_name, overlay_flag)
          elsif linked_property_names.include?(property_name)
            load_linked_objects(property_name, filter, false, [I18n.locale], overlay_flag)
          elsif embedded_property_names.include?(property_name)
            load_embedded_objects(property_name, filter, !property_definition&.dig('translated'), [I18n.locale], overlay_flag)
          elsif asset_property_names.include?(property_name) # no overlay
            load_asset_relation(property_name)&.first
          elsif schedule_property_names.include?(property_name)
            load_schedule(property_name, overlay_flag)
          elsif timeseries_property_names.include?(property_name)
            load_timeseries(property_name)
          elsif collection_property_names.include?(property_name)
            load_collections(property_name)
          elsif geo_property_names.include?(property_name)
            load_geometry(property_name)
          else
            raise NotImplementedError
          end
      end

      def load_virtual_attribute(property_name, locale = I18n.locale)
        DataCycleCore::Utility::Virtual::Base.virtual_values(property_name, self, locale)
      end

      def load_json_attribute(property_name, property_definition, _overlay_flag)
        if property_definition['storage_location'] == 'column'
          send(property_name)
        else
          convert_to_type(
            property_definition['type'],
            send(NEW_STORAGE_LOCATION[property_definition['storage_location']])&.dig(property_name.to_s),
            property_definition
          )
        end
      end

      def load_included_data(property_name, property_definition, _overlay_flag)
        sub_property_definitions = property_definition.try(:[], 'properties')
        raise StandardError, "Template for included data #{property_name} has no Subproperties defined." if sub_property_definitions.blank?

        thing_data = load_subproperty_hash(
          sub_property_definitions,
          property_definition['storage_location'],
          send(NEW_STORAGE_LOCATION[property_definition['storage_location']]).try(:[], property_name)
        )

        OpenStructHash.new(thing_data, self, property_definition).freeze
      end

      def load_subproperty_hash(sub_properties, storage_location, sub_properties_data)
        sub_properties.map { |key, item|
          if item['type'] == 'object' && item['storage_location'] == storage_location
            { key => OpenStructHash.new(load_subproperty_hash(item['properties'], storage_location, sub_properties_data.try(:[], key.to_s))).freeze }
          elsif item['storage_location'] == storage_location
            { key => convert_to_type(item['type'], sub_properties_data.try(:[], key.to_s), sub_properties) }
          elsif item['storage_location'] == 'column'
            { key => send(key) }
          else
            raise StandardError, "Template includes wrong definitions for included sub_property #{key}, given: #{item}!"
          end
        }.inject(&:merge)
      end

      delegate :convert_to_type, to: :'DataCycleCore::MasterData::DataConverter'
      delegate :convert_to_string, to: :'DataCycleCore::MasterData::DataConverter'
      delegate :string_to_geographic, to: :'DataCycleCore::MasterData::DataConverter'

      def parent_templates
        DataCycleCore::ThingTemplate
          .from("thing_templates, jsonb_each(schema -> 'properties') property_name")
          .where(
            "property_name.value ->> 'type' = ? AND property_name.value ->> 'template_name' = ?",
            'embedded',
            template_name
          )
          .template_things
          .map { |t| t.content_type == 'embedded' ? t.parent_templates : t }
          .flatten
      end

      def feature_attributes(prefix = '')
        @feature_attributes ||= Hash.new do |h, key|
          h[key] = DataCycleCore.features
            .select { |_, v| !v[:only_config] == true }
            .keys
            .map { |f| ModuleService.safe_load_module("Feature::#{f.to_s.classify}", 'Datacycle').try("#{prefix}attribute_keys", self) }
            .flatten
        end
        @feature_attributes[prefix]
      end

      def allowed_feature_attribute?(key)
        @allowed_feature_attribute ||= Hash.new do |h, k|
          h[k] = feature_attributes.include?(key) ? feature_attributes('allowed_').include?(key) : true
        end

        @allowed_feature_attribute[key]
      end

      def self.shared_ordered_properties(user)
        contents = includes(:primary_classification_aliases, classification_aliases: [:classification_alias_path, :classification_tree_label])

        ordered_properties = all.thing_templates.template_things
          .map { |t|
            t.schema['properties'].dc_deep_dup
              .except!(*(DataCycleCore.internal_data_attributes + ['id']))
              .keep_if { |k, v|
                !k.in?(t.computed_property_names + t.virtual_property_names + t.asset_property_names) &&
                  (v['type'] != 'linked' || v['link_direction'] != 'inverse') &&
                  t.allowed_feature_attribute?(k.attribute_name_from_key) &&
                  v.dig('ui', 'bulk_edit', 'disabled').to_s != 'true'
              }
              .sort_by { |_, v| v['sorting'] }
              .map! do |(k, v)|
              [k, v.except('api', 'content_score').deep_reject { |p_k, p_v| p_k == 'show' || (!p_v.is_a?(FalseClass) && p_v.blank?) }]
            end
          }
          .reduce(:&)
          .to_h

        tree_label_names = ordered_properties.values.pluck('tree_label').compact.uniq
        tree_labels = DataCycleCore::ClassificationTreeLabel.where(name: tree_label_names).index_by(&:name) if tree_label_names.present?

        ordered_properties.keep_if do |_, v|
          v['type'] != 'classification' || DataCycleCore::ClassificationService.visible_classification_tree?(tree_labels[v['tree_label']], 'edit')
        end

        contents.find_each do |t|
          ordered_properties.select! do |k, v|
            user.can_attribute?(key: k, definition: v, content: t, scope: :update, context: :editor, options: { edit_scope: 'bulk_edit' })
          end
        end

        ordered_properties
      end

      def self.shared_template_features
        all.thing_templates.template_things
          .map { |t| t.schema['features'].to_a }
          .reduce(:&)
          .to_h
      end

      def set_property_value(property_name, property_definition, value)
        raise NotImplementedError unless PLAIN_PROPERTY_TYPES.include?(property_definition['type'])

        ActiveSupport::Deprecation.warn("DataCycleCore::Content::Content setter should not be used any more! property_name: #{property_name}, property_definition: #{property_definition}, value: #{value}, caller: #{caller.join("\n")}") unless Rails.env.test?

        send(
          :"#{NEW_STORAGE_LOCATION[property_definition['storage_location']]}=",
          (send(NEW_STORAGE_LOCATION[property_definition['storage_location']]) || {}).merge({ property_name => value })
        )

        reload_memoized attibute_cache_key(property_name)
      end

      def set_memoized_attribute(key, value, filter = nil, overlay_flag = false)
        definition = properties_for(key)

        return send(:"#{key}=", value) if definition['storage_location'] == 'column'

        attibute_cache_key = attibute_cache_key(key, filter, overlay_flag)

        (@get_property_value ||= {})[attibute_cache_key] =
          if plain_property_names.include?(key) ||
             geo_property_names.include?(key)
            convert_to_type(definition['type'], value, definition)
          elsif value.is_a?(ActiveRecord::Relation) || value.is_a?(ActiveRecord::Base)
            value
          elsif value.is_a?(::Array) && value.first.is_a?(ActiveRecord::Base)
            value.first.class.unscoped.by_ordered_values(value.pluck(:id)).tap { |rel| rel.send(:load_records, value) }
          elsif linked_property_names.include?(key)
            DataCycleCore::Thing.by_ordered_values(value)
          elsif embedded_property_names.include?(key)
            # TODO: allow initialization of thing without persisting it, to correctly initialize default_values for embedded objects
            value.blank? || (value.is_a?(::Array) && value.all?(::String) && value.all?(&:uuid?)) ? DataCycleCore::Thing.by_ordered_values(value) : DataCycleCore::Thing.none
          elsif classification_property_names.include?(key)
            DataCycleCore::Classification.by_ordered_values(value)
          elsif asset_property_names.include?(key)
            DataCycleCore::Asset.by_ordered_values(value).first
          elsif schedule_property_names.include?(key)
            DataCycleCore::Schedule.by_ordered_values(value)
          elsif timeseries_property_names.include?(key)
            DataCycleCore::Timeseries.by_ordered_values(value)
          elsif collection_property_names.include?(key)
            DataCycleCore::Collection.by_ordered_values(value)
          else # rubocop:disable Lint/DuplicateBranch
            value
          end
      end

      def template_missing?
        thing_template.nil?
      end

      def template_name_missing?
        template_name.blank?
      end

      def validate_template!
        return self unless template_name_missing? || template_missing?

        error = if template_name_missing? && template_missing?
                  +':template_name or :thing_template is required!' # don't freeze string
                elsif thing_template.nil?
                  "template '#{template_name}' does not exist!"
                else
                  "template_name is missing for template: #{thing_template.to_json}!"
                end

        raise ActiveModel::MissingAttributeError, error
      end

      def thing_template?
        !template_missing?
      end

      private

      def attibute_cache_key(key, filter = nil, overlay_flag = false)
        filter = nil if linked_property_names.exclude?(key) && embedded_property_names.exclude?(key)

        "#{key}_#{I18n.locale if translatable_property?(key)}_#{filter&.hash}_#{overlay_flag && overlay_property_names.include?(key)}"
      end

      def move_changes_to_previous_changes
        self.previous_datahash_changes = datahash_changes&.deep_dup
      end

      def update_template_properties
        reload_template_definition

        self.boost = thing_template.boost
        self.content_type = thing_template.content_type
      end

      def update_template_defaults
        DataCycleCore::UpdateTemplateDefaultsJob.perform_later(id)
      end

      def reload_template_definition
        remove_instance_variable(:@content_template) if instance_variable_defined?(:@content_template)
        remove_instance_variable(:@translatable_property_names) if instance_variable_defined?(:@translatable_property_names)
        remove_instance_variable(:@untranslatable_property_names) if instance_variable_defined?(:@untranslatable_property_names)
        remove_instance_variable(:@get_property_value) if instance_variable_defined?(:@get_property_value)
        remove_instance_variable(:@enabled_features) if instance_variable_defined?(:@enabled_features)
        remove_instance_variable(:@feature_attributes) if instance_variable_defined?(:@feature_attributes)
        remove_instance_variable(:@allowed_feature_attribute) if instance_variable_defined?(:@allowed_feature_attribute)
      end

      def reload_memoized(key = nil)
        remove_instance_variable(:@_current_collection) if instance_variable_defined?(:@_current_collection)
        remove_instance_variable(:@_current_recursive_collection) if instance_variable_defined?(:@_current_recursive_collection)
        remove_instance_variable(:@_current_rc_with_leafs) if instance_variable_defined?(:@_current_rc_with_leafs)
        remove_instance_variable(:@_current_recursive_ccs) if instance_variable_defined?(:@_current_recursive_ccs)
        remove_instance_variable(:@datahash_changes) if instance_variable_defined?(:@datahash_changes)

        if key.present?
          @get_property_value&.delete(key)
        elsif instance_variable_defined?(:@get_property_value)
          remove_instance_variable(:@get_property_value)
        end
      end

      # [TODO] initialize attributes from template properties
      # def initialize_template_properties
      #   untranslatable_string_property_names.each do |pn|
      #     singleton_class.class_eval do
      #       store_accessor :metadata, pn.to_sym
      #       attribute pn.to_sym, :'thing/string'
      #     end
      #   end
      # end
    end
  end
end
