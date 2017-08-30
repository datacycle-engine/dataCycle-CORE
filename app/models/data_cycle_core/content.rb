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
        if (plain_property_names + linked_property_names + classification_property_names).include?(property_name)
          { property_name.to_s => send(property_name)}
        elsif included_property_names.include?(property_name)
          embedded_hash = send(property_name).to_h
          { property_name.to_s => embedded_hash.blank? ? nil : embedded_hash}
        elsif embedded_property_names.include?(property_name)
          { property_name.to_s => send(property_name).map(&:to_h)}
        else
          raise StandardError.new("cannot determine how to serialize #{property_name}")
        end
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

      puts property_name

      # linked data via embeddedLink/embeddedLinkArray
      if linked_property_names.include?(property_name)
        load_linked_data(
            "DataCycleCore::#{property_definition['type_name'].singularize.camelize}",
            send(property_definition['storage_location'])[property_name.to_s]
          )
      # included subobjects
      elsif included_property_names.include?(property_name)
        load_included_data(
          property_name,
          property_definition
        )

      # embeddedObject stored in differnt table
      elsif embedded_property_names.include?(property_name) && property_definition['storage_location'] != self.class.table_name
        puts "--> different table"
        send(property_definition['storage_location'])

      # embeddedObject stored in same table
      elsif embedded_property_names.include?(property_name) && property_definition['storage_location'] == self.class.table_name
        puts "--> same table"
        load_linked_data(
            self.class.to_s,
            send('metadata')[property_name.to_s + '_hasPart']
          )
      # for classification relations load the uuid-array
      elsif classification_property_names.include?(property_name)
        load_relation_ids(
          property_definition['storage_type'],
          property_definition['type_name']
        )
      # plain properties (e.g. string,text, ... )
      elsif PLAIN_PROPERTY_TYPES.include?(property_definition['storage_type'])
        send(property_definition['storage_location'])[property_name.to_s]
      else
        raise NotImplementedError
      end
    end

    def load_linked_data(class_name, ids)
      puts "class_name: #{class_name} / ids: #{ids}"
      class_name.safe_constantize.find(ids) rescue []
    end

    def load_included_data(property_name, property_definition)
      sub_property_definitions = property_definition.try(:[], 'properties')
      raise StandardError.new("Template for included data #{property_name} has no Subproperties defined.") if sub_property_definitions.blank?
      OpenStructHash.new(
        load_subproperty_hash(sub_property_definitions,
          property_definition['storage_location'],
          send(property_definition['storage_location']).try(:[], property_name)
        )
      ).compact.freeze
    end

    def load_subproperty_hash(sub_properties, storage_location, sub_properties_data)
      sub_properties.map{ |key, item|
        if item['type'] == 'object' && item['storage_location'] == storage_location
          {key => OpenStructHash.new(load_subproperty_hash(item['properties'], storage_location, sub_properties_data.try(:[],key.to_s))).compact.freeze}
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
        where("classification_tree_labels.name = ?", tree_label).
        pluck(:classification_id)
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
