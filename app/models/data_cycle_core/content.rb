module DataCycleCore
  class Content < DataHash
    self.abstract_class = true

    def property_definitions
      metadata['validation']['properties'] rescue []
    end

    def method_missing(name, *args, &block)
      property_definition = property_definitions[name.to_s.gsub(/=$/, '')]

      if name.to_s.ends_with?('=') && property_definition && ['metadata', 'content', 'properties'].include?(property_definition['storage_location'])
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0)") unless args.size == 1

        send(property_definition['storage_location'] + '=', 
          send(property_definition['storage_location']).merge({name.to_s.gsub(/=$/, '') => args.first})
        )        
      elsif property_definition && ['metadata', 'content', 'properties'].include?(property_definition['storage_location'])
        raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0)") unless args.blank?

        send(property_definition['storage_location'])[name.to_s]
      else
        super
      end
    end
  end
end
