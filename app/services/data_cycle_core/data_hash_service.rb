module DataCycleCore
  class DataHashService

    def self.flatten_datahash_value(datahash, template_hash, debug=false)

      datahash = self.flatten_recursive(datahash.to_h, template_hash)

      if debug == true
        #raise datahash.inspect
      end

      return datahash

    end

    def self.get_internal_data(storage_location, value)

      internal_objects = []
      if !value.empty? && value.count > 0
        value.each do |object|
          internal_object = ("DataCycleCore::"+storage_location.classify).constantize.
              find_by(id: object['id'])
          internal_objects.push(internal_object) unless internal_object.blank?
        end
      else
        return nil
      end

      return internal_objects

    end

    def self.get_internal_template(storage_location, name, description)

      internal_template = ("DataCycleCore::"+storage_location.classify).constantize.
          find_by(template: true, headline: name, description: description)

      if internal_template.blank?
        return nil
      end

      return internal_template

    end

    private

      def self.flatten_recursive(datahash, template_hash)

        temp_datahash = {}

        datahash.each do |key,value|

          properties = template_hash['properties'][key]

          if value.is_a?(::Hash)

            if properties['type'] == 'object' && !properties['editor']['type'].nil? && properties['editor']['type'] == 'embeddedObject'
              object_properties = self.get_internal_template(properties['storage_location'],properties['name'],properties['description'])
              temp_value = []

              value.values.each do |object_value|
                temp_value.push(self.flatten_recursive(object_value, object_properties.metadata['validation']))
              end

              value = temp_value
            end

          else
            #todo: add more casts ?
            if properties['type'] == 'number'
              value = value.to_i
            end

          end

          temp_datahash[key] = value
        end

        return temp_datahash
      end

  end

end