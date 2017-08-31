module DataCycleCore
  class Content < ApplicationRecord
    NESTED_STORAGE_LOCATIONS = ['metadata', 'content', 'properties']

    PLAIN_PROPERTY_TYPES = ['string', 'text', 'number', 'geographic']

    self.abstract_class = true

    def property_definitions
      metadata['validation']['properties'] rescue {}
    end

    def method_missing(name, *args, &block)
      property_definition = property_definitions.try(:[], name.to_s.gsub(/=$/, ''))
      if property_definition && name.to_s.ends_with?('=')
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 1)") unless args.size == 1

        set_property_value(name.to_s.gsub(/=$/, ''), property_definition, args.first)
      elsif property_definition
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0)") unless args.blank?

        get_property_value(name.to_s.gsub(/=$/, ''), property_definition)
      else
        super
      end
    end

    def respond_to?(method_name, include_private = false)
      property_names.map{|item| [item.to_sym, (item.to_s+"=").to_sym]}.flatten.include?(method_name.to_sym) || super
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
          ['key', 'metadata', 'classification_relation'].include?(definition['storage_location']) ||
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

    def to_h
      property_names.map { |property_name|
        property_value =
        if plain_property_names.include?(property_name)
          send(property_name)
        elsif classification_property_names.include?(property_name)
          send(property_name).try(:pluck, :classification_id)
        elsif linked_property_names.include?(property_name)
          send(property_name).try(:pluck, :id) || send(property_name).try(:id)
        elsif included_property_names.include?(property_name)
          embedded_hash = send(property_name).to_h
          embedded_hash.blank? ? nil : embedded_hash
        elsif embedded_property_names.include?(property_name)
          send(property_name).map(&:get_data_hash).compact #to propagate the releasable functionality
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


    private

    def get_property_value(property_name, property_definition)
      # linked data via embeddedLink/embeddedLinkArray
      # only uuid(s) stored in content-data_set
      if linked_property_names.include?(property_name)
        #puts "for #{property_name}, in #{property_definition['storage_location']}, load [#{property_name.to_s}]"
        #send(property_definition['storage_location'])[property_name.to_s]
        loaded_data = load_linked_data(
            "DataCycleCore::#{property_definition['type_name'].singularize.camelize}",
            send(property_definition['storage_location'])[property_name.to_s]
          )

      # included subobjects
      # properties stored in this content-data_set directly
      elsif included_property_names.include?(property_name)
        load_included_data(
            property_name,
            property_definition
          )

      # embeddedObject stored in different table
      # relation is hadled via a separate table
      # embeddedObject is stored in a separate content-data_set
      # all properties from the embeddedObject are handled within this content-data_set
      elsif embedded_property_names.include?(property_name) && property_definition['storage_location'] != self.class.table_name
        send(property_definition['storage_location'])

      # embeddedObject stored in same table
      # relation is handled via "property_name"+"_hasPart" uuid(s) array
      # embeddedObject is stored in a separate content-data_set
      # all properties from the embeddedObject are handled within this content-data_set
      elsif embedded_property_names.include?(property_name) && property_definition['storage_location'] == self.class.table_name
        load_linked_data(
            self.class.to_s,
            send('metadata')[property_name.to_s + '_hasPart']
          )

      # for classification relations
      # classifications are stored in the respective relations Table
      # ( "classification"+"content_table")
      elsif classification_property_names.include?(property_name)
        load_relation_ids(
            property_definition['storage_type'],
            property_definition['type_name']
          )

      # plain properties (e.g. string,text, ... )
      # non-structured properties of this content-data_set
      elsif PLAIN_PROPERTY_TYPES.include?(property_definition['storage_type'])
        send(property_definition['storage_location'])[property_name.to_s]
      else
        raise NotImplementedError
      end
    end

    def load_linked_data(class_name, ids)
      class_name.safe_constantize.find(ids) rescue nil
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

    def load_relation_ids(storage_type, tree_label)
      class_string = "DataCycleCore::"+storage_type.classify
      class_id = self.class.to_s.demodulize.foreign_key
      class_string.constantize.
        where(class_id => id).
        joins(classification: [classification_groups: [classification_alias: [classification_trees: [:classification_tree_label]]]]).
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
