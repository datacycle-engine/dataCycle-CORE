# frozen_string_literal: true

module DataCycleCore
  module Content
    class Content < ApplicationRecord
      NESTED_STORAGE_LOCATIONS = ['metadata', 'content'].freeze
      # TODO: remove after final refactor_data_definition migration
      NEW_STORAGE_LOCATION = {
        'value' => 'metadata',
        'translated_value' => 'content',
        'column' => 'column'
      }.freeze
      PLAIN_PROPERTY_TYPES = ['key', 'string', 'number', 'datetime', 'boolean', 'geographic'].freeze

      self.abstract_class = true

      attr_accessor :datahash, :webhook_source

      DataCycleCore.features
        .select { |_, v| !v.dig(:only_config) == true }
        .each_key do |key|
          module_name = ('DataCycleCore::Feature::Content::' + key.to_s.classify).constantize
          include module_name if ('DataCycleCore::Feature::' + key.to_s.classify).constantize.enabled?
        end
      extend  DataCycleCore::Common::ArelBuilder
      include DataCycleCore::Content::ContentRelations
      extend  DataCycleCore::Content::ContentFilters
      include DataCycleCore::Content::DestroyContent
      include DataCycleCore::Content::DataHashUtility
      include DataCycleCore::Content::Extensions::Content
      include DataCycleCore::Content::Extensions::ContentWarnings

      after_save :reload_memoized

      def method_missing(name, *args, &block)
        property_definition = property_definitions.try(:[], name.to_s.gsub(/=$/, ''))
        if property_definition && name.to_s.ends_with?('=')
          raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1)" unless args.size == 1
          set_property_value(name.to_s.gsub(/=$/, ''), property_definition, args.first)
        elsif property_definition
          raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" if args.size.positive?
          get_property_value(name.to_s.gsub(/=$/, ''), property_definition)
        else
          super
        end
      end

      def respond_to?(method_name, include_all = false)
        (property_names.map { |item| [item.to_sym, (item.to_s + '=').to_sym] }.flatten + linked_property_names.map { |item| item + '_ids' }).include?(method_name.to_sym) || super
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

      def schema_type
        schema&.dig('schema_type')
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
        schema&.dig('properties') || {}
      end

      def property_names
        property_definitions.keys
      end

      def properties_for(property_name)
        property_definitions[property_name]
      end

      def translatable_property_names
        @translatable_property_names ||= begin
          property_definitions.select { |property_name, definition|
            translatable_property?(property_name, definition)
          }.keys
        end
      end

      def translated_columns
        @translated_columns ||= (self.class.to_s + '::Translation').constantize.column_names
      end

      def translatable_property?(property_name, property_definition = nil)
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

      def combined_property_names
        property_definitions.select { |_, definition|
          definition.dig('api', 'transformation', 'method') == 'combine'
        }.sort_by { |_k, v| v.dig('sorting') }.to_h.keys
      end

      def plain_property_names
        name_property_selector { |definition| PLAIN_PROPERTY_TYPES.include?(definition['type']) }
      end

      def linked_property_names
        name_property_selector { |definition| definition['type'] == 'linked' }
      end

      def embedded_property_names
        name_property_selector { |definition| definition['type'] == 'embedded' }
      end

      def included_property_names
        name_property_selector { |definition| definition['type'] == 'object' }
      end

      def computed_property_names
        name_property_selector { |definition| definition['type'] == 'computed' }
      end

      def classification_property_names
        name_property_selector { |definition| definition['type'] == 'classification' }
      end

      def asset_property_names
        name_property_selector { |definition| definition['type'] == 'asset' }
      end

      def schedule_property_names
        name_property_selector { |definition| definition['type'] == 'schedule' }
      end

      def searchable_embedded_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'embedded' && definition['advanced_search'] == true
        }.keys
      end

      def advanced_search_property_names
        property_definitions.select { |_, definition|
          !['embedded', 'object', 'linked'].include?(definition['type']) && definition['advanced_search'] == true
        }.keys
      end

      def advanced_included_search_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'object' && definition['advanced_search'] == true
        }.keys
      end

      def geo_properties
        property_selector { |definition| definition['type'] == 'geographic' }
      end

      def global_property_names
        name_property_selector { |definition| definition['global'] == true }
      end

      def search_property_names
        name_property_selector { |definition| definition['search'] == true }
      end

      def to_h(timestamp = Time.zone.now)
        property_names.map { |property_name|
          property_value = attribute_to_h(property_name, timestamp)
          { property_name.to_s => property_value }
        }.inject(&:merge).deep_stringify_keys
      end

      def attribute_to_h(property_name, timestamp = Time.zone.now)
        if property_name == 'id' && history?
          send(self.class.to_s.split('::')[1].foreign_key) # for history records original_key is saved in "content"_id
        elsif plain_property_names.include?(property_name)
          send(property_name)
        elsif classification_property_names.include?(property_name)
          send(property_name).try(:pluck, :id)
        elsif linked_property_names.include?(property_name)
          linked_array = get_property_value(property_name, property_definitions[property_name])
          linked_array.presence || []
        elsif included_property_names.include?(property_name)
          embedded_hash = send(property_name).to_h
          embedded_hash.presence
        elsif embedded_property_names.include?(property_name)
          embedded_array = send(property_name)
          embedded_array = embedded_array.map { |item| item.get_data_hash(timestamp) } if embedded_array.present?
          embedded_array.blank? ? [] : embedded_array.compact
        elsif asset_property_names.include?(property_name)
          send(property_name)
        elsif computed_property_names.include?(property_name)
          send(property_name)
        elsif schedule_property_names.include?(property_name)
          send(property_name).to_h.presence
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
        respond_to?('history_valid')
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
        features = []
        features << collect_properties.map { |k| schema&.dig('properties', *k, 'features')&.keys }
        features << schema&.dig('features')&.keys
        features << DataCycleCore.features.select { |_, v| v[:enabled] }.keys.map(&:to_s)
        features.flatten.uniq.compact
      end

      def get_property_value(property_name, property_definition)
        @get_property_value ||= Hash.new do |h, key|
          h[key] =
            if plain_property_names.include?(key[0])
              load_json_attribute(key[0], key[1])
            elsif included_property_names.include?(key[0])
              load_included_data(key[0], key[1])
            elsif classification_property_names.include?(key[0])
              load_classifications(key[0])
            elsif linked_property_names.include?(key[0])
              load_linked_objects(key[0])
            elsif embedded_property_names.include?(key[0])
              load_embedded_objects(key[0])
            elsif asset_property_names.include?(key[0])
              load_asset_relation(key[0])
            elsif computed_property_names.include?(key[0])
              load_computed_attribute(key[0], key[1])
            elsif schedule_property_names.include?(key[0])
              load_schedule(key[0])
            else
              raise NotImplementedError
            end
        end
        @get_property_value[[property_name, property_definition, I18n.locale]]
      end

      def load_json_attribute(property_name, property_definition)
        convert_to_type(
          property_definition['type'],
          send(NEW_STORAGE_LOCATION[property_definition['storage_location']])&.dig(property_name.to_s)
        )
      end

      def load_computed_attribute(property_name, property_definition)
        convert_to_type(
          property_definition.dig('compute', 'type'),
          send(NEW_STORAGE_LOCATION[property_definition['storage_location']])&.dig(property_name.to_s)
        )
      end

      def load_included_data(property_name, property_definition)
        sub_property_definitions = property_definition.try(:[], 'properties')
        raise StandardError, "Template for included data #{property_name} has no Subproperties defined." if sub_property_definitions.blank?
        OpenStructHash.new(
          load_subproperty_hash(
            sub_property_definitions,
            property_definition['storage_location'],
            send(NEW_STORAGE_LOCATION[property_definition['storage_location']]).try(:[], property_name)
          )
        ).freeze
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

      def convert_to_type(type, value)
        DataCycleCore::MasterData::DataConverter.convert_to_type(type, value)
      end

      def convert_to_string(type, value)
        DataCycleCore::MasterData::DataConverter.convert_to_string(type, value)
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
        all.includes(:primary_classification_aliases, classification_aliases: [:classification_alias_path, :classification_tree_label])
          .find_each.map { |t|
            t.schema.dig('properties')
              .except(*(DataCycleCore.internal_data_attributes + ['id']))
              .select { |k, v|
                ['computed', 'asset'].exclude?(v['type']) &&
                  user.can?(:show, DataCycleCore::DataAttribute.new(k, v, {}, t, :edit)) &&
                  user.can?(:edit, DataCycleCore::DataAttribute.new(k, v, {}, t, :edit)) &&
                  t.allowed_feature_attribute?(k.attribute_name_from_key)
              }
              .sort_by { |_, v| v['sorting'] }
              .to_h
              .map { |k, v| [k, v.except('sorting', 'api').deep_reject { |p_k, p_v| p_k == 'show' || (!p_v.is_a?(FalseClass) && p_v.blank?) }] }
          }
          .inject(:&).to_h
          .select { |_, v| (v['type'] != 'classification' || DataCycleCore::ClassificationService.visible_classification_tree?(v['tree_label'], 'edit')) }
      end

      def self.shared_template_features
        all.map { |t| t.schema['features'].to_a }.inject(:&).to_h
      end

      def set_property_value(property_name, property_definition, value)
        raise NotImplementedError unless PLAIN_PROPERTY_TYPES.include?(property_definition['type'])
        send(NEW_STORAGE_LOCATION[property_definition['storage_location']] + '=',
             (send(NEW_STORAGE_LOCATION[property_definition['storage_location']]) || {}).merge({ property_name => value }))
        reload_memoized [property_name, property_definition]
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
