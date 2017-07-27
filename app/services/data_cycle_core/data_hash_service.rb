module DataCycleCore
  class DataHashService

    def self.flatten_datahash_value(datahash, template_hash, debug=false)

      datahash = self.flatten_recursive(datahash.to_h, template_hash)

      if debug == true
        raise datahash.inspect
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

    def self.get_object_params(storage_location, template_name, template_description)
      template = self.get_internal_template(storage_location, template_name, template_description)
      datahash = self.get_params_from_hash(template.metadata['validation'])
      return datahash
    end

    def self.create_internal_object(storage_location, template_name, template_description, object_params, current_user)

      object = ("DataCycleCore::"+storage_location.classify).constantize.new(object_params)

      template = self.get_internal_template(storage_location, template_name, template_description)
      validation = template.metadata['validation']

      object.metadata = { 'validation' => validation }
      object.save

      if !object_params[:datahash].nil?
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],object.metadata['validation'])
        datahash['creator'] = current_user[:id]
      else
        return nil
      end

      object.set_data_hash(datahash)

      #validate ?
      if object.save
        return object
      else
        return nil
      end

    end

    private

      def self.get_params_from_hash(template_hash)
        temp_params = []

        template_hash['properties'].each do |key,value|

          if value['type'] == 'object' && !value['editor']['type'].nil? && (value['editor']['type'] == 'embeddedObject' || value['editor']['type'] == 'objectBrowser')
            object_properties = self.get_internal_template(value['storage_location'],value['name'],value['description'])
            key = {key.to_sym => self.get_params_from_hash(object_properties.metadata['validation'])}
          elsif value['type'] == 'object' && !value['properties'].nil? && !value['properties'].empty?
            key = {key.to_sym => self.get_params_from_hash(value)}
          elsif value['type'] == 'classificationTreeLabel' || value['type'] == 'embeddedLinkArray'
            key = {key.to_sym => []}
          else
            key = key.to_sym
          end

          temp_params.push(key)
        end

        return temp_params
      end

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
          elsif value.is_a?(::Array)
            value = value.reject { |v| v.empty? }
          else
            #todo: add more casts ?
            if properties['type'] == 'number' && !properties['validations'].nil? && !properties['validations']['format'].nil? && properties['validations']['format'] == 'float'
              value = value.to_f
            elsif properties['type'] == 'number'
              value = value.to_i
            end

          end

          temp_datahash[key] = value
        end

        return temp_datahash
      end

  end

end