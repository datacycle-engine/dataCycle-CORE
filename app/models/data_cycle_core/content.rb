module DataCycleCore
  class Content < ApplicationRecord
    NESTED_STORAGE_LOCATIONS = ['metadata', 'content', 'properties']
    PLAIN_PROPERTY_TYPES = ['string', 'text', 'number', 'geographic']

    self.abstract_class = true

    attr_accessor :datahash

    include ContentRelations
    include Subscribable
    include Releasable


    def property_definitions
      metadata['validation']['properties'] rescue {}
    end

    def method_missing(name, *args, &block)
      property_definition = property_definitions.try(:[], name.to_s.gsub(/=$/, ''))
      if property_definition && name.to_s.ends_with?('=')
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 1)") unless args.size == 1

        set_property_value(name.to_s.gsub(/=$/, ''), property_definition, args.first)
      elsif property_definition
        timestamp = args.try(:first)
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0)") if (args.size == 1 && timestamp.nil) || args.size > 1

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
      (property_names.map{|item| [item.to_sym, (item.to_s+"=").to_sym]}.flatten + linked_property_names.map{|item| item+'_ids'}).include?(method_name.to_sym) || super
    end


    def property_names
      property_definitions.keys
    end

    def translatable_property_names
      translated_columns = (self.class.to_s + "::Translation").constantize.column_names

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
      property_definitions.select { |property_name, definition|
        PLAIN_PROPERTY_TYPES.include?(definition['type'])
      }.keys
    end

    def linked_property_names
      property_definitions.select { |property_name, definition|
        definition['type'] == 'embeddedLink' || definition['type'] == 'embeddedLinkArray'
      }.keys
    end

    def embedded_property_names
      property_definitions.select { |property_name, definition|
        definition['type'] == 'object' && !NESTED_STORAGE_LOCATIONS.include?(definition['storage_location'])
      }.keys
    end

    def included_property_names
      property_definitions.select { |property_name, definition|
        definition['type'] == 'object' &&  NESTED_STORAGE_LOCATIONS.include?(definition['storage_location'])
      }.keys
    end

    def classification_property_names
      property_definitions.select { |property_name, definition|
        definition['type'] == 'classificationTreeLabel'
      }.keys
    end

    def search_property_names
      property_definitions.select { |property_name, definition|
        definition['search'] == true
      }.keys
    end

    def to_h(timestamp = Time.zone.now)
      property_names.map { |property_name|
        property_value =
        if property_name == "id" && is_history?
          send(self.class.to_s.split("::")[1].foreign_key) # for history records original_key is saved in "content"_id
        elsif plain_property_names.include?(property_name)
          send(property_name)
        elsif classification_property_names.include?(property_name)
          send(property_name).try(:pluck, :classification_id)
        elsif linked_property_names.include?(property_name)
          get_property_value(property_name, property_definitions[property_name], timestamp, false)
        elsif included_property_names.include?(property_name)
          embedded_hash = send(property_name).to_h
          embedded_hash.blank? ? nil : embedded_hash
        elsif embedded_property_names.include?(property_name)
          embedded_array = send(property_name)
          embedded_array = embedded_array.map{|item| item.get_data_hash(timestamp)} unless embedded_array.blank?
          embedded_array.blank? ? [] : embedded_array.compact
        else
          raise StandardError.new("cannot determine how to serialize #{property_name}")
        end
        { property_name.to_s => property_value }
      }.inject(&:merge).deep_stringify_keys
    end

    def verify
      if (translatable_property_names & untranslatable_property_names).size > 0
        inconsistent_properties = (translatable_property_names & untranslatable_property_names)

        raise StandardError.new("cannot determine whether some properties (#{inconsistent_properties.join(',')}) are translatable or not")
      end

      self
    end

    def is_history?
      respond_to? "history_valid"
    end

    def as_of(timestamp)
      return self if updated_at.nil? || timestamp > updated_at
      return nil if is_history?

      base_content_class = self.class.to_s
      history_table = "#{base_content_class}::History".safe_constantize.arel_table
      history_table_translation = "#{base_content_class}::History::Translation".safe_constantize.arel_table
      history_id = "#{base_content_class}::History".safe_constantize.table_name.singularize.foreign_key.to_sym

      return_data =
      self.histories.
        joins(
          history_table.join(history_table_translation).
          on(history_table[:id].eq(history_table_translation[history_id])).
          join_sources
        ).
        where(
          Arel::Nodes::InfixOperation.new( "@>",
            history_table_translation[:history_valid],
            Arel::Nodes::SqlLiteral.new("CAST('#{timestamp.to_s(:long_usec)}' AS TIMESTAMP WITH TIME ZONE)")
          )
        ).order(history_table[:updated_at])#.first #rescue self
      return return_data.last
    end

    def embedded_relations
      embedded_property_names.map { |property_name|
         {name: property_name, table: property_definitions[property_name]['storage_location']} if property_definitions[property_name]['storage_location'] != self.class.table_name
      }.compact.uniq
    end

    def embedded_self_property_names
      embedded_property_names.select { |property_name|
        property_definitions[property_name]['storage_location'] == self.class.table_name
      }
    end

    private

    def get_property_value(property_name, property_definition, timestamp = Time.zone.now, object = true)
      # linked data via embeddedLink/embeddedLinkArray
      # only uuid(s) stored in content-data_set
      if linked_property_names.include?(property_name)
        load_linked_data(
            property_definition['type_name'],
            send(property_definition['storage_location'])[property_name.to_s],
            timestamp,
            object
          )

      # included subobjects
      # properties stored in this content-data_set directly
      elsif included_property_names.include?(property_name)
        load_included_data(
            property_name,
            property_definition
          )

      # embeddedObject stored in different table
      # relation is hadled via a separate table (an ActiveRecord::Relation has to be defined)
      # embeddedObject is stored in a separate content-data_set
      # all properties from the embeddedObject are handled within this content-data_set
      elsif embedded_property_names.include?(property_name) && !same_table?(property_definition['storage_location'])
        load_embedded_objects(
            property_definition['storage_location']
          )

      # embeddedObject stored in same table
      # relation is handled via "property_name"+"_hasPart" uuid(s) array
      # embeddedObject is stored in a separate content-data_set
      # all properties from the embeddedObject are handled within this content-data_set
      elsif embedded_property_names.include?(property_name) && same_table?(property_definition['storage_location'])
        load_embedded_objects_same_table(
            send('metadata')[property_name.to_s + '_hasPart']
          )

      # for classification relations
      # classification relations are stored in the classification_contents table
      elsif classification_property_names.include?(property_name)
        load_relation_ids(property_definition['type_name'])

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
      if self.class.table_name.split('_').last == 'histories'
        history =  self.class.table_name.split('_')[0..-2].join('_').pluralize == storage_location
      end
      self.class.table_name == storage_location || history
    end

    def load_embedded_objects(relation_name)
      is_history? ? send("#{relation_name.singularize}_histories") : send(relation_name)
    end

    def load_embedded_objects_same_table(ids)
      self.class.to_s.safe_constantize.find(ids) rescue nil
    end

    def load_linked_data(type_name, ids, timestamp = Time.zone.now, objects = true)
      return ids unless objects
      class_name = "DataCycleCore::#{type_name.singularize.camelize}"
      class_name.safe_constantize.find(ids).map{|item| item.as_of(timestamp)} rescue nil
    end

    def load_included_data(property_name, property_definition)
      sub_property_definitions = property_definition.try(:[], 'properties')
      raise StandardError.new("Template for included data #{property_name} has no Subproperties defined.") if sub_property_definitions.blank?
      OpenStructHash.new(
        load_subproperty_hash(sub_property_definitions,
          property_definition['storage_location'],
          send(property_definition['storage_location']).try(:[], property_name)
        )
      ).freeze
    end

    def load_subproperty_hash(sub_properties, storage_location, sub_properties_data)
      sub_properties.map{ |key, item|
        if item['type'] == 'object' && item['storage_location'] == storage_location
          {key => OpenStructHash.new(load_subproperty_hash(item['properties'], storage_location, sub_properties_data.try(:[],key.to_s))).freeze}
        elsif item['storage_location'] == storage_location
          {key => sub_properties_data.try(:[],key.to_s)}
        elsif item['storage_location'] == 'column'
          {key => send(key)}
        else
          raise StandardError.new("Template includes wrong definitions for included sub_property #{key}, given: #{item}!")
        end
      }.inject(&:merge)
    end

    def load_relation_ids(tree_label)
      class_string = "DataCycleCore::ClassificationContent"
      class_string += "::History" if is_history?
      class_id = 'content_data_id'
      class_id = 'content_data_history_id' if is_history?
      class_string.constantize.
        where(class_id => id).
        joins(classification: [classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]]]).
        where("classification_tree_labels.name = ?", tree_label)
    end

    def set_property_value(property_name, property_definition, value)
      if PLAIN_PROPERTY_TYPES.include?(property_definition['storage_type'])
        send(property_definition['storage_location'] + '=',
            (send(property_definition['storage_location']) || {}).merge({property_name => value})
          )
      else
        raise NotImplementedError
      end
    end
  end
end
