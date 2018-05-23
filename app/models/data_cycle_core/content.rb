module DataCycleCore
  class Content < ApplicationRecord
    NESTED_STORAGE_LOCATIONS = ['metadata', 'content']
    # TODO: remove after final refactor_data_definition migration
    NEW_STORAGE_LOCATION = {
      'value' => 'metadata',
      'translated_value' => 'content',
      'column' => 'column'
    }
    PLAIN_PROPERTY_TYPES = ['key', 'string', 'number', 'datetime', 'boolean', 'geographic']

    self.abstract_class = true

    attr_accessor :datahash, :webhook_source

    extend Common::ArelBuilder
    extend ContentFilters

    include MasterData::DataConverter
    include ContentRelations
    include Subscribable
    include Releasable

    def property_definitions
      schema['properties']
    rescue StandardError
      {}
    end

    def method_missing(name, *args, &block)
      property_definition = property_definitions.try(:[], name.to_s.gsub(/=$/, ''))
      # puts "#{name.to_s.gsub(/=$/, '')} // #{property_definition} // #{args.first}"
      if property_definition && name.to_s.ends_with?('=')
        raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1)" unless args.size == 1

        set_property_value(name.to_s.gsub(/=$/, ''), property_definition, args.first)
      elsif property_definition
        timestamp = args.try(:first)
        raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" if (args.size == 1 && timestamp.nil) || args.size > 1

        if timestamp.nil?
          get_property_value(name.to_s.gsub(/=$/, ''), property_definition)
        else
          get_property_value(name.to_s.gsub(/=$/, ''), property_definition, timestamp)
        end
      else
        super
      end
    end

    def respond_to?(method_name, include_private = false)
      (property_names.map { |item| [item.to_sym, (item.to_s + '=').to_sym] }.flatten + linked_property_names.map { |item| item + '_ids' }).include?(method_name.to_sym) || super
    end

    def property_names
      property_definitions.keys
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

    def included_property_names
      property_definitions.select { |_, definition|
        definition['type'] == 'object' || NESTED_STORAGE_LOCATIONS.include?(NEW_STORAGE_LOCATION[definition['storage_location']])
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

    def to_h(timestamp = Time.zone.now)
      property_names.map { |property_name|
        property_value =
          if property_name == 'id' && history?
            send(self.class.to_s.split('::')[1].foreign_key) # for history records original_key is saved in "content"_id
          elsif plain_property_names.include?(property_name)
            send(property_name)
          elsif classification_property_names.include?(property_name)
            send(property_name).try(:pluck, :id)
          elsif linked_property_names.include?(property_name)
            linked_array = get_property_value(property_name, property_definitions[property_name], timestamp)
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
          else
            raise StandardError, "cannot determine how to serialize #{property_name}"
          end
        { property_name.to_s => property_value }
      }.inject(&:merge).deep_stringify_keys
    end

    def verify
      unless (translatable_property_names & untranslatable_property_names).empty?
        inconsistent_properties = (translatable_property_names & untranslatable_property_names)

        raise StandardError, "cannot determine whether some properties (#{inconsistent_properties.join(',')}) are translatable or not"
      end

      self
    end

    def history?
      respond_to? 'history_valid'
    end

    def content_type?(types)
      if types.is_a?(Array)
        types.include?(schema&.dig('content_type'))
      else
        types == schema&.dig('content_type')
      end
    end

    def as_of(timestamp)
      return self if updated_at.blank? || timestamp.blank? || timestamp >= updated_at
      return self if history?

      base_content_class = self.class.to_s
      history_table = "#{base_content_class}::History".safe_constantize.arel_table
      history_table_translation = "#{base_content_class}::History::Translation".safe_constantize.arel_table
      history_id = "#{base_content_class}::History".safe_constantize.table_name.singularize.foreign_key.to_sym

      return_data =
        histories
          .joins(
            history_table.join(history_table_translation)
              .on(history_table[:id].eq(history_table_translation[history_id]))
              .join_sources
          )
          .where(
            Arel::Nodes::InfixOperation.new(
              '@>',
              history_table_translation[:history_valid],
              Arel::Nodes::SqlLiteral.new("CAST('#{timestamp.to_s(:long_usec)}' AS TIMESTAMP WITH TIME ZONE)")
            )
          ).order(history_table_translation[:history_valid])
      return_data.last
    end

    def embedded_relations
      embedded_property_names.map { |property_name|
        { name: property_name, table: property_definitions[property_name]['linked_table'] }
      }.compact.uniq
    end

    def linked_relations
      linked_property_names.map { |property_name|
        { name: property_name, table: property_definitions[property_name]['linked_table'] }
      }.compact.uniq
    end

    def geo_properties
      property_definitions.select { |_, v| v['type'] == 'geographic' }
    end

    # private

    def get_property_value(property_name, property_definition, timestamp = Time.zone.now)
      # linked data via embeddedLink/embeddedLinkArray
      # handled like embedded_objects with delete=false
      if linked_property_names.include?(property_name)
        load_embedded_objects(
          property_definition['linked_table'],
          property_name,
          true
        )

        # plain properties (e.g. string,text, ... )
        # non-structured properties of this content-data_set
      elsif PLAIN_PROPERTY_TYPES.include?(property_definition['type'])
        load_json_attribute(
          property_name,
          property_definition
        )

        # included subobjects
        # properties stored in this content-data_set directly
      elsif included_property_names.include?(property_name)
        load_included_data(
          property_name,
          property_definition
        )

        # embeddedObject stored via content_content(s)(_histories)
        # all properties from the embeddedObject are handled within this content-data_set
      elsif embedded_property_names.include?(property_name)
        load_embedded_objects(
          property_definition['linked_table'],
          property_name
        )

        # for classification relations
        # classification relations are stored in the classification_contents table
      elsif classification_property_names.include?(property_name)
        load_relation_ids(property_name)

        # for asset relations
        # asset relations are stored in the asset_contents table
      elsif asset_property_names.include?(property_name)
        load_asset_relation_ids(property_name)

      else
        raise NotImplementedError
      end
    end

    def same_table?(storage_location)
      history = false
      history = self.class.table_name.split('_')[0..-2].join('_').pluralize == storage_location if self.class.table_name.ends_with?('_histories')
      self.class.table_name == storage_location || history
    end

    def load_json_attribute(property_name, property_definition)
      convert_to_type(
        property_definition['type'],
        send(NEW_STORAGE_LOCATION[property_definition['storage_location']]).try(:[], property_name.to_s)
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

    def load_embedded_objects(target_name, relation_name, linked = false)
      target_class = history? ? "DataCycleCore::#{target_name.classify}::History" : "DataCycleCore::#{target_name.classify}"
      target_class = "DataCycleCore::#{target_name.classify}" if linked
      selector = target_name < self.class.table_name
      content_one_data = [nil, target_class, '']
      content_two_data = [id, self.class.to_s, relation_name]
      where_hash = ['a', 'b'].map { |abselector|
        if history?
          ["content_#{abselector}_history_id".to_sym,
           "content_#{abselector}_history_type".to_sym,
           "relation_#{abselector}".to_sym]
        else
          ["content_#{abselector}_id".to_sym,
           "content_#{abselector}_type".to_sym,
           "relation_#{abselector}".to_sym]
        end
      }.flatten
        .zip(selector ? content_one_data + content_two_data : content_two_data + content_one_data).to_h.compact
      relation_table = history? ? :content_content_histories : :content_contents
      join_table = selector ? :content_content_a_history : :content_content_b_history if history?
      join_table = selector ? :content_content_a : :content_content_b unless history?
      order_string = selector ? 'content_contents.order_b ASC' : 'content_contents.order_a ASC'
      order_string = selector ? 'content_content_histories.order_b ASC' : 'content_content_histories.order_a ASC' if history?

      query = target_class.constantize.joins(join_table)
      where_hash.each do |key, value|
        query = query.where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["#{relation_table}.#{key} = ?", value]))
      end
      query.order(order_string)
    end

    def load_relation_ids(relation_name)
      if history?
        join_relation = :classification_content_histories
        class_id = :content_data_history_id
        class_type = :content_data_history_type
      else
        join_relation = :classification_contents
        class_id = :content_data_id
        class_type = :content_data_type
      end
      DataCycleCore::Classification.joins(join_relation).where(join_relation => { class_type => self.class.to_s, class_id => id, relation: relation_name })
    end

    def load_asset_relation_ids(relation_name)
      join_relation = :asset_contents
      class_id = :content_data_id
      DataCycleCore::Asset.joins(join_relation).where(join_relation => { class_id => id, relation: relation_name })
    end

    def set_property_value(property_name, property_definition, value)
      if PLAIN_PROPERTY_TYPES.include?(property_definition['type'])
        send(NEW_STORAGE_LOCATION[property_definition['storage_location']] + '=',
             (send(NEW_STORAGE_LOCATION[property_definition['storage_location']]) || {}).merge({ property_name => value }))
      else
        raise NotImplementedError
      end
    end
  end
end
