module DataCycleCore
  class Content < ApplicationRecord
    NESTED_STORAGE_LOCATIONS = ['metadata', 'content', 'properties']
    PLAIN_PROPERTY_TYPES = ['string', 'text', 'number', 'geographic']

    self.abstract_class = true

    attr_accessor :datahash, :webhook_source

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
        ['content', 'properties'].include?(definition['storage_location']) ||
          (definition['storage_location'] == 'column' && translated_columns.include?(property_name))
      }.keys
    end

    def untranslatable_property_names
      untranslated_columns = self.class.column_names

      property_definitions.select { |property_name, definition|
        ['key', 'metadata'].include?(definition['storage_location']) ||
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
        definition['type'] == 'embeddedLink' || definition['type'] == 'embeddedLinkArray'
      }.keys
    end

    def embedded_property_names
      property_definitions.select { |_, definition|
        definition['type'] == 'object' && !NESTED_STORAGE_LOCATIONS.include?(definition['storage_location'])
      }.keys
    end

    def included_property_names
      property_definitions.select { |_, definition|
        definition['type'] == 'object' &&  NESTED_STORAGE_LOCATIONS.include?(definition['storage_location'])
      }.keys
    end

    def classification_property_names
      property_definitions.select { |_, definition|
        definition['type'] == 'classificationTreeLabel'
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
          if property_name == 'id' && is_history?
            send(self.class.to_s.split('::')[1].foreign_key) # for history records original_key is saved in "content"_id
          elsif plain_property_names.include?(property_name)
            send(property_name)
          elsif classification_property_names.include?(property_name)
            send(property_name).try(:pluck, :id)
          elsif linked_property_names.include?(property_name)
            get_property_value(property_name, property_definitions[property_name], timestamp, false)
          elsif included_property_names.include?(property_name)
            embedded_hash = send(property_name).to_h
            embedded_hash.presence
          elsif embedded_property_names.include?(property_name)
            embedded_array = send(property_name)
            embedded_array = embedded_array.map { |item| item.get_data_hash(timestamp) } unless embedded_array.blank?
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

    def is_history?
      respond_to? 'history_valid'
    end

    def as_of(timestamp)
      return self if updated_at.blank? || timestamp.blank? || timestamp >= updated_at
      return self if is_history?

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
        { name: property_name, table: property_definitions[property_name]['storage_location'] }
      }.compact.uniq
    end

    def linked_relations
      linked_property_names.map { |property_name|
        { name: property_name, table: property_definitions[property_name]['type_name'], type: property_definitions[property_name]['type'] }
      }.compact.uniq
    end

    private

    def get_property_value(property_name, property_definition, timestamp = Time.zone.now, object = true)
      # linked data via embeddedLink/embeddedLinkArray
      # handled like embedded_objects with delete=false
      if linked_property_names.include?(property_name)
        if object
          load_embedded_objects(
            property_definition['type_name'],
            property_name,
            true
          )
        elsif property_definition['type'] == 'embeddedLink'
          load_embedded_objects(
            property_definition['type_name'],
            property_name,
            true
          ).try(:first).try(:id)
        else
          load_embedded_objects(
            property_definition['type_name'],
            property_name,
            true
          ).try(:ids)
        end

        # included subobjects
        # properties stored in this content-data_set directly
      elsif included_property_names.include?(property_name)
        load_included_data(
          property_name,
          property_definition
        )

        # embeddedObject stored via contnet_content(s)(_histories)
        # all properties from the embeddedObject are handled within this content-data_set
      elsif embedded_property_names.include?(property_name)
        load_embedded_objects(
          property_definition['storage_location'],
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

        # plain properties (e.g. string,text, ... )
        # non-structured properties of this content-data_set
      elsif PLAIN_PROPERTY_TYPES.include?(property_definition['storage_type'])
        send(property_definition['storage_location']).try(:[], property_name.to_s)
      else
        raise NotImplementedError
      end
    end

    def same_table?(storage_location)
      history = false
      history = self.class.table_name.split('_')[0..-2].join('_').pluralize == storage_location if self.class.table_name.split('_').last == 'histories'
      self.class.table_name == storage_location || history
    end

    def load_embedded_objects(target_name, relation_name, linked = false)
      target_class = is_history? ? "DataCycleCore::#{target_name.classify}::History" : "DataCycleCore::#{target_name.classify}"
      target_class = "DataCycleCore::#{target_name.classify}" if linked
      selector = target_name < self.class.table_name
      content_one_data = [nil, target_class, '']
      content_two_data = [id, self.class.to_s, relation_name]
      where_hash = ['a', 'b'].map { |abselector|
        if is_history?
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
      relation_table = is_history? ? :content_content_histories : :content_contents
      join_table = selector ? :content_content_a_history : :content_content_b_history if is_history?
      join_table = selector ? :content_content_a : :content_content_b unless is_history?
      query = target_class.constantize.joins(join_table)
      where_hash.each do |key, value|
        query = query.where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["#{relation_table}.#{key} = ?", value]))
      end
      query
    end

    def load_included_data(property_name, property_definition)
      sub_property_definitions = property_definition.try(:[], 'properties')
      raise StandardError, "Template for included data #{property_name} has no Subproperties defined." if sub_property_definitions.blank?
      OpenStructHash.new(
        load_subproperty_hash(sub_property_definitions,
                              property_definition['storage_location'],
                              send(property_definition['storage_location']).try(:[], property_name))
      ).freeze
    end

    def load_subproperty_hash(sub_properties, storage_location, sub_properties_data)
      sub_properties.map { |key, item|
        if item['type'] == 'object' && item['storage_location'] == storage_location
          { key => OpenStructHash.new(load_subproperty_hash(item['properties'], storage_location, sub_properties_data.try(:[], key.to_s))).freeze }
        elsif item['storage_location'] == storage_location
          { key => sub_properties_data.try(:[], key.to_s) }
        elsif item['storage_location'] == 'column'
          { key => send(key) }
        else
          raise StandardError, "Template includes wrong definitions for included sub_property #{key}, given: #{item}!"
        end
      }.inject(&:merge)
    end

    def load_relation_ids(relation_name)
      if is_history?
        join_relation = :classification_content_histories
        class_id = :content_data_history_id
      else
        join_relation = :classification_contents
        class_id = :content_data_id
      end
      DataCycleCore::Classification.joins(join_relation).where(join_relation => { class_id => id, relation: relation_name })
    end

    def load_asset_relation_ids(relation_name)
      join_relation = :asset_contents
      class_id = :content_data_id
      DataCycleCore::Asset.joins(join_relation).where(join_relation => { class_id => id, relation: relation_name })
    end

    def set_property_value(property_name, property_definition, value)
      if PLAIN_PROPERTY_TYPES.include?(property_definition['storage_type'])
        send(property_definition['storage_location'] + '=',
             (send(property_definition['storage_location']) || {}).merge({ property_name => value }))
      else
        raise NotImplementedError
      end
    end
  end
end
