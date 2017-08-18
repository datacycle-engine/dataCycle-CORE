module DataCycleCore
  class Content < DataHash
    NESTED_STORAGE_LOCATIONS = ['metadata', 'content', 'properties']

    PLAIN_PROPERTY_TYPES = ['string', 'text', 'number', 'geographic']

    self.abstract_class = true

    def property_definitions
      metadata['validation']['properties'] rescue []
    end

    def method_missing(name, *args, &block)
      property_definition = property_definitions.try(:[], name.to_s.gsub(/=$/, ''))

      if property_definition && name.to_s.ends_with?('=')
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0)") unless args.size == 1

        set_property_value(name.to_s.gsub(/=$/, ''), property_definition, args.first)
      elsif property_definition
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0)") unless args.blank?

        get_property_value(name.to_s.gsub(/=$/, ''), property_definition)
      else
        super
      end
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

    def verify
      if (translatable_property_names & untranslatable_property_names).size > 0
        inconsistent_properties = (translatable_property_names & untranslatable_property_names)

        raise StandardError.new("cannot determine whether some properties (#{inconsistent_properties.join(',')}) are translatable or not")
      end

      self
    end


    private

    def get_property_value(property_name, property_definition)
      if PLAIN_PROPERTY_TYPES.include?(property_definition['storage_type'])
        send(property_definition['storage_location'])[property_name.to_s]      
      else
        raise NotImplementedError
      end
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
