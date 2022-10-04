# frozen_string_literal: true

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
      PLAIN_PROPERTY_TYPES = ['key', 'string', 'number', 'date', 'datetime', 'boolean', 'geographic', 'slug'].freeze
      WEBHOOK_ACCESSORS = [:webhook_source, :webhook_as_of, :webhook_run_at, :webhook_priority, :prevent_webhooks, :synchronous_webhooks].freeze

      self.abstract_class = true

      attr_accessor :datahash, :datahash_changes, :original_id, :duplicate_id, :local_import, *WEBHOOK_ACCESSORS
      attr_writer :webhook_data

      DataCycleCore.features.select { |_, v| !v.dig(:only_config) == true }.each_key do |key|
        feature = ('DataCycleCore::Feature::' + key.to_s.classify).constantize
        include feature.content_module if feature.enabled? && feature.content_module
      end
      extend  DataCycleCore::Common::ArelBuilder
      include DataCycleCore::Content::ContentRelations
      extend  DataCycleCore::Content::Searchable
      include DataCycleCore::Content::DestroyContent
      include DataCycleCore::Content::DataHashUtility
      include DataCycleCore::Content::Extensions::Content
      include DataCycleCore::Content::Extensions::ContentWarnings
      include DataCycleCore::Content::Extensions::Api
      include DataCycleCore::Content::Extensions::SyncApi
      include DataCycleCore::Content::Extensions::Geojson
      include DataCycleCore::Content::Extensions::DefaultValue
      include DataCycleCore::Content::Extensions::ComputedValue
      prepend DataCycleCore::Content::Extensions::Translation

      after_save :reload_memoized

      def reload(options = nil)
        reload_memoized

        super(options)
      end

      def webhook_data
        return @webhook_data if defined? @webhook_data

        @webhook_data = OpenStruct.new
      end

      def method_missing(name, *args, &block)
        original_name = name.to_s
        root_name = name.to_s.delete_suffix('=').delete_suffix("_#{overlay_name}")
        property_definition = property_definitions.try(:[], root_name)
        if property_definition && name.to_s.ends_with?('=')
          raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1)" unless args.size == 1
          set_property_value(name.to_s.delete_suffix('='), property_definition, args.first)
        elsif property_definition
          overlay_flag = original_name.ends_with?(overlay_name)
          original_name = original_name.delete_suffix("_#{overlay_name}") if DataCycleCore::Feature::Overlay.enabled? && original_name.ends_with?(overlay_name)

          if original_name.in?(embedded_property_names) || original_name.in?(linked_property_names)
            raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1)" if args.size > 1
            get_property_value(original_name, property_definition, args.first, overlay_flag & original_name.in?(overlay_property_names))
          elsif original_name.in?(timeseries_property_names)
            raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1)" if args.size > 3
            get_property_value(original_name, property_definition, args.first, args&.try(:second), args&.try(:third))
          else
            raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" if args.size.positive?
            get_property_value(original_name, property_definition, nil, overlay_flag & original_name.in?(overlay_property_names))
          end
        else
          super
        end
      end

      def respond_to?(method_name, include_all = false)
        (property_names.map { |item| [item.to_sym, (item.to_s + '=').to_sym, (item.to_s + "_#{overlay_name}").to_sym] }.flatten +
          linked_property_names.map { |item| item + '_ids' }).include?(method_name.to_sym) || super
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
        !i18n_errors&.any? { |(_k, v)| v.present? }
      end

      def content_template
        return @content_template if defined? @content_template
        @content_template = DataCycleCore::Thing.find_by(template: true, template_name: template_name)
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
        external_source.present?
      end

      def schema_type
        schema&.dig('schema_type')
      end

      def schema_ancestors
        Array.wrap(schema&.dig('schema_ancestors')).then { |p| p.present? && !p.first.is_a?(::Array) ? [p] : p }
      end

      def translatable?
        schema&.dig('features', 'translatable', 'allowed') || false
      end

      def creatable?(scope)
        schema.dig('content_type') != 'embedded' &&
          schema.dig('features', 'creatable', 'allowed') &&
          (
          schema.dig('features', 'creatable', 'scope').blank? ||
            schema.dig('features', 'creatable', 'scope')&.include?(scope)
        )
      end

      def property_definitions
        schema&.[]('properties') || {}
      end

      def property_names
        property_definitions.keys
      end
      alias properties property_names

      def properties_for(property_name, include_overlay = false)
        include_overlay ? property_definitions.merge(add_overlay_property_definitions)[property_name] : property_definitions[property_name]
      end

      def translatable_property_names
        @translatable_property_names ||= property_definitions.select { |property_name, definition|
          translatable_property?(property_name, definition)
        }.keys
      end

      def translated_columns
        @translated_columns ||= (self.class.to_s + '::Translation').constantize.column_names
      end

      def translatable_property?(property_name, property_definition = nil)
        property_definition ||= property_definitions[property_name]
        property_definition['storage_location'] == 'translated_value' ||
          (property_definition['storage_location'] == 'column' && translated_columns.include?(property_name))
      end

      def untranslatable_property_names
        untranslated_columns = self.class.column_names

        property_definitions.select { |property_name, definition|
          definition['storage_location'] == 'value' || definition['type'] == 'key' ||
            (definition['storage_location'] == 'column' && untranslated_columns.include?(property_name))
        }.keys
      end

      def combined_property_names(api_version = nil)
        property_definitions.select { |_, definition|
          if api_version.present? && definition.dig('api', api_version).present?
            definition.dig('api', api_version, 'transformation', 'method') == 'combine'
          else
            definition.dig('api', 'transformation', 'method') == 'combine'
          end
        }.sort_by { |_k, v| v.dig('sorting') }.to_h.keys
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
          [k, v.dig('properties').keys.map { |prop_key| prop_key.camelize(:lower) }]
        end
      end

      def plain_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| PLAIN_PROPERTY_TYPES.include?(definition['type']) }
      end

      def virtual_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['virtual'].present? }
      end

      def linked_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['type'] == 'linked' }
      end

      def embedded_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['type'] == 'embedded' }
      end

      def included_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['type'] == 'object' }
      end

      def computed_property_names(include_overlay = false)
        @computed_property_names ||= Hash.new do |h, key|
          h[key] = name_property_selector(key) { |definition| definition['compute'].present? }
        end
        @computed_property_names[include_overlay]
      end

      def default_value_property_names(include_overlay = false)
        @default_value_property_names ||= Hash.new do |h, key|
          h[key] = name_property_selector(key) { |definition| definition['default_value'].present? }
        end
        @default_value_property_names[include_overlay]
      end

      def classification_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['type'] == 'classification' }
      end

      def asset_property_names
        name_property_selector { |definition| definition['type'] == 'asset' }
      end

      def schedule_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['type'].in?(['schedule', 'opening_time']) }
      end

      def timeseries_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['type'] == 'timeseries' }
      end

      def external_property_names
        name_property_selector { |definition| definition.dig('external') }
      end

      def untranslatable_embedded_property_names
        name_property_selector { |definition| definition['type'] == 'embedded' && !definition.dig('translatable') }
      end

      def translatable_embedded_property_names
        name_property_selector { |definition| definition['type'] == 'embedded' && definition.dig('translatable') }
      end

      def searchable_embedded_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'embedded' && definition['advanced_search'] == true
        }.keys
      end

      def advanced_search_property_names
        name_property_selector { |definition| ['embedded', 'object', 'linked', 'classification'].exclude?(definition['type']) && definition['advanced_search'] == true }
      end

      def advanced_included_search_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'object' && definition['advanced_search'] == true
        }.keys
      end

      def advanced_classification_property_names
        name_property_selector { |definition| definition['type'] == 'classification' && definition['advanced_search'] == true }
      end

      def geo_properties(include_overlay = false)
        property_selector(include_overlay) { |definition| definition['type'] == 'geographic' }
      end

      def global_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['global'] == true }
      end

      def search_property_names(include_overlay = false)
        name_property_selector(include_overlay) { |definition| definition['search'] == true }
      end

      def embedded_title_property_name
        return unless embedded?

        @embedded_title_property_name ||=
          name_property_selector { |definition| definition['type'] == 'string' && definition.dig('ui', 'is_title') == true }.first || 'name'
      end

      def exif_property_names
        name_property_selector { |definition| definition['exif'].present? }
      end

      def schema_sorted
        sorted_properties = schema.dig('properties').map { |key, value| { key => value } }.sort_by { |i| i.values.first.dig('sorting') }.inject(&:merge)
        schema.deep_dup.merge({ 'properties' => sorted_properties })
      end

      # returns data the same way, as .as_json
      def to_h(timestamp = Time.zone.now)
        Array.wrap(property_names)
          .difference(virtual_property_names)
          .index_with { |k| attribute_to_h(k, timestamp) }
          .deep_stringify_keys
      end

      # returns data the same way, as .as_json
      def to_h_partial(partial_properties, timestamp = Time.zone.now)
        Array.wrap(partial_properties)
          .intersection(property_names)
          .difference(virtual_property_names)
          .index_with { |k| attribute_to_h(k, timestamp) }
          .deep_stringify_keys
      end

      # returns data the same way, as .as_json
      def attribute_to_h(property_name, timestamp = Time.zone.now)
        if property_name == 'id' && history?
          send(self.class.to_s.split('::')[1].foreign_key) # for history records original_key is saved in "content"_id
        elsif plain_property_names.include?(property_name)
          send(property_name)&.as_json
        elsif classification_property_names.include?(property_name) || linked_property_names.include?(property_name)
          send(property_name).try(:pluck, :id)
        elsif included_property_names.include?(property_name)
          embedded_hash = send(property_name).to_h
          embedded_hash.presence
        elsif embedded_property_names.include?(property_name)
          embedded_array = send(property_name)
          embedded_array = embedded_array.map { |item| item.get_data_hash(timestamp) } if embedded_array.present?
          embedded_array.blank? ? [] : embedded_array.compact
        elsif asset_property_names.include?(property_name)
          send(property_name)&.id
        elsif schedule_property_names.include?(property_name)
          schedule_array = send(property_name)
          schedule_array = schedule_array.map(&:to_h).presence
          schedule_array.blank? ? [] : schedule_array.compact
        elsif timeseries_property_names.include?(property_name)
          []
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
        respond_to?(:history_valid)
      end

      def collect_properties(definition = schema, parents = [])
        key_paths = []
        definition&.dig('properties')&.each do |k, v|
          if v&.key?('properties')
            key_paths << collect_properties(v, parents + [k, 'properties'])
          else
            key_paths << (parents.present? ? [parents + [k]] : [k])
          end
        end
        key_paths.flatten(1)
      end

      def enabled_features
        @enabled_features ||= DataCycleCore::FeatureService.enabled_features(schema)
      end

      def get_property_value(property_name, property_definition, filter = nil, overlay_flag = false, add_filter = nil)
        @get_property_value ||= Hash.new do |h, key|
          h[key] =
            if virtual_property_names.include?(key[0])
              load_virtual_attribute(key[0], key[2])
            elsif plain_property_names(true).include?(key[0])
              load_json_attribute(key[0], key[1], key[4])
            elsif included_property_names(true).include?(key[0])
              load_included_data(key[0], key[1], key[4])
            elsif classification_property_names(true).include?(key[0])
              load_classifications(key[0], key[4])
            elsif linked_property_names(true).include?(key[0])
              load_linked_objects(key[0], key[3], false, [key[2]], key[4])
            elsif embedded_property_names(true).include?(key[0])
              load_embedded_objects(key[0], key[3], !key.dig(1, 'translated'), [key[2]], key[4])
            elsif asset_property_names.include?(key[0]) # no overlay
              load_asset_relation(key[0])&.first
            elsif schedule_property_names(true).include?(key[0])
              load_schedule(key[0], key[4])
            elsif timeseries_property_names.include?(key[0])
              load_timeseries(key[0], key[3], key[4], key[5])
            else
              raise NotImplementedError
            end
        end

        @get_property_value[[property_name, property_definition, I18n.locale, filter, overlay_flag, add_filter]]
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

        OpenStructHash.new(thing_data).freeze
      end

      def load_subproperty_hash(sub_properties, storage_location, sub_properties_data)
        sub_properties.map { |key, item|
          if item['type'] == 'object' && item['storage_location'] == storage_location
            { key => OpenStructHash.new(load_subproperty_hash(item['properties'], storage_location, sub_properties_data.try(:[], key.to_s))).freeze }
          elsif item['storage_location'] == storage_location
            { key => convert_to_type(item['type'], sub_properties_data.try(:[], key.to_s)) }
          elsif item['storage_location'] == 'column'
            { key => send(key) }
          else
            raise StandardError, "Template includes wrong definitions for included sub_property #{key}, given: #{item}!"
          end
        }.inject(&:merge)
      end

      def convert_to_type(type, value, definition = nil, content = nil)
        DataCycleCore::MasterData::DataConverter.convert_to_type(type, value, definition, self || content)
      end

      def convert_to_string(type, value, content = nil)
        DataCycleCore::MasterData::DataConverter.convert_to_string(type, value, self || content)
      end

      def parent_templates
        DataCycleCore::Thing
          .from("things, jsonb_each(schema -> 'properties') property_name")
          .where("things.template = ? AND value ->> 'type' = ? AND value ->> 'template_name' = ?", true, 'embedded', template_name)
          .map { |t| t.content_type == 'embedded' ? t.parent_templates : t }
          .flatten
      end

      def feature_attributes(prefix = '')
        @feature_attributes ||= Hash.new do |h, key|
          h[key] = DataCycleCore.features
            .select { |_, v| !v.dig(:only_config) == true }
            .keys
            .map { |f| "DataCycleCore::Feature::#{f.to_s.classify}".constantize.try("#{prefix}attribute_keys", self) }
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
        contents = all.includes(:primary_classification_aliases, classification_aliases: [:classification_alias_path, :classification_tree_label])

        ordered_properties = contents
          .select('DISTINCT ON (things.template_name) things.schema')
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
              .map! { |(k, v)| [k, v.except('sorting', 'api').deep_reject { |p_k, p_v| p_k == 'show' || (!p_v.is_a?(FalseClass) && p_v.blank?) }] }
          }
          .reduce(:&)
          .to_h
          .keep_if { |_, v| (v['type'] != 'classification' || DataCycleCore::ClassificationService.visible_classification_tree?(v['tree_label'], 'edit')) }

        contents.find_each do |t|
          ordered_properties.select! do |k, v|
            user.can?(:edit, DataCycleCore::DataAttribute.new(k, v, {}, t, :edit, :bulk_edit)) &&
              user.can?(:update, DataCycleCore::DataAttribute.new(k, v, {}, t, :update))
          end
        end

        ordered_properties
      end

      def self.shared_template_features
        all
          .select('DISTINCT ON (things.template_name) things.schema')
          .map { |t| t.schema['features'].to_a }
          .reduce(:&)
          .to_h
      end

      def set_property_value(property_name, property_definition, value)
        Appsignal.send_error(e) do |transaction|
          transaction.set_namespace("method set_property_value is deprecated use set_data_hash instead. Thing: #{id}(#{template_name}) - #{property_name}")
        end
        raise NotImplementedError unless PLAIN_PROPERTY_TYPES.include?(property_definition['type'])
        ActiveSupport::Deprecation.warn("DataCycleCore::Content::Content setter should not be used any more! property_name: #{property_name}, property_definition: #{property_definition}, value: #{value}")
        send(NEW_STORAGE_LOCATION[property_definition['storage_location']] + '=',
             (send(NEW_STORAGE_LOCATION[property_definition['storage_location']]) || {}).merge({ property_name => value }))
        reload_memoized [property_name, property_definition]
      end

      def set_memoized_attribute(key, value)
        return if DataCycleCore::DataHashService.blank?(value)

        definition = properties_for(key)

        return send("#{key}=", value) if definition['storage_location'] == 'column'

        if plain_property_names.include?(key)
          value = convert_to_type(definition['type'], value, definition)
        elsif value.is_a?(ActiveRecord::Relation) || (value.is_a?(::Array) && value.first.is_a?(ActiveRecord::Base))
          return (@get_property_value ||= {})[[key, definition, I18n.locale, nil, false, nil]] = value
        elsif linked_property_names.include?(key) || embedded_property_names.include?(key)
          value = DataCycleCore::Thing.where(id: value)
        elsif classification_property_names.include?(key)
          value = DataCycleCore::Classification.where(id: value)
        elsif asset_property_names.include?(key)
          value = DataCycleCore::Asset.where(id: value)
        end

        (@get_property_value ||= {})[[key, definition, I18n.locale, nil, false, nil]] = value
      end

      private

      def reload_memoized(key = nil)
        return unless instance_variable_defined?(:@get_property_value)

        @get_property_value.delete(key) && return if key.present?

        remove_instance_variable(:@get_property_value) if instance_variable_defined?(:@get_property_value)
      end
    end
  end
end
