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

      DataCycleCore.features.each_key do |key|
        module_name = ('DataCycleCore::Feature::Content::' + key.to_s.classify).constantize
        include module_name if ('DataCycleCore::Feature::' + key.to_s.classify).constantize.enabled?
      end
      extend  DataCycleCore::Common::ArelBuilder
      include DataCycleCore::MasterData::DataConverter
      include ContentRelations
      extend  ContentFilters
      include DestroyContent
      include DataHashUtility
      include Extensions::Content

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
        types&.flatten&.map(&:to_s)&.include?(schema&.dig('content_type'))
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
      rescue StandardError
        {}
      end

      def property_names
        property_definitions.keys
      end

      def properties_for(property_name)
        property_definitions[property_name]
      end

      def translatable_property_names
        translated_columns = (self.class.to_s + '::Translation').constantize.column_names

        property_definitions.select { |property_name, definition|
          definition['storage_location'] == 'translated_value' ||
            (definition['storage_location'] == 'column' && translated_columns.include?(property_name))
        }.keys
      end

      def untranslatable_property_names
        untranslated_columns = self.class.column_names

        property_definitions.select { |property_name, definition|
          definition['storage_location'] == 'value' || definition['type'] == 'key' ||
            (definition['storage_location'] == 'column' && untranslated_columns.include?(property_name))
        }.keys
      end

      def plain_property_names
        property_definitions.select { |_, definition|
          PLAIN_PROPERTY_TYPES.include?(definition['type'])
        }.keys
      end

      def linked_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'linked'
        }.keys
      end

      def embedded_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'embedded'
        }.keys
      end

      def global_property_names
        property_definitions.select { |_, definition|
          definition['global'] == true
        }.keys
      end

      def included_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'object'
        }.keys
      end

      def computed_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'computed'
        }.keys
      end

      def classification_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'classification'
        }.keys
      end

      def asset_property_names
        property_definitions.select { |_, definition|
          definition['type'] == 'asset'
        }.keys
      end

      def search_property_names
        property_definitions.select { |_, definition|
          definition['search'] == true
        }.keys
      end

      def geo_properties
        property_definitions.select { |_, val| val['type'] == 'geographic' }
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

      def as_of(_timestamp)
        self
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
        if plain_property_names.include?(property_name)
          load_json_attribute(property_name, property_definition)
        elsif included_property_names.include?(property_name)
          load_included_data(property_name, property_definition)
        elsif classification_property_names.include?(property_name)
          load_classifications(property_name)
        elsif linked_property_names.include?(property_name)
          load_linked_objects(property_name)
        elsif embedded_property_names.include?(property_name)
          load_embedded_objects(property_name)
        elsif asset_property_names.include?(property_name)
          load_asset_relation(property_name)
        elsif computed_property_names.include?(property_name)
          load_computed_attribute(property_name, property_definition)
        else
          raise NotImplementedError
        end
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

      def load_asset_relation(relation_name)
        DataCycleCore::Asset.joins(:asset_contents)
          .where(asset_contents: { content_data_id: id, relation: relation_name })
      end

      def set_property_value(property_name, property_definition, value)
        raise NotImplementedError unless PLAIN_PROPERTY_TYPES.include?(property_definition['type'])
        send(NEW_STORAGE_LOCATION[property_definition['storage_location']] + '=',
             (send(NEW_STORAGE_LOCATION[property_definition['storage_location']]) || {}).merge({ property_name => value }))
      end
    end
  end
end
