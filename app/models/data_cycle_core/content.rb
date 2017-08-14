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

      if property_definition && NESTED_STORAGE_LOCATIONS.include?(property_definition['storage_location']) && name.to_s.ends_with?('=')
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0)") unless args.size == 1

        set_property_value(name.to_s.gsub(/=$/, ''), property_definition, args.first)
      elsif property_definition && NESTED_STORAGE_LOCATIONS.include?(property_definition['storage_location'])
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0)") unless args.blank?

        get_property_value(name.to_s.gsub(/=$/, ''), property_definition)
      else
        super
      end
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
