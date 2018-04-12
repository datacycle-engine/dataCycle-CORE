module DataCycleCore
  class DataHashService
    # TODO: refactor: class => module
    extend NormalizeService
    require 'hashdiff'

    def self.flatten_datahash_value(datahash, template_hash, debug = false)
      datahash = flatten_recursive(datahash.to_h, template_hash)

      raise datahash.inspect if debug == true

      datahash
    end

    def self.data_hash_is_dirty?(data_hash, orig_data_hash)
      !HashDiff.diff(normalize_data_hash(data_hash), normalize_data_hash(orig_data_hash), array_path: true).blank?
    end

    def self.get_internal_data(storage_location, value)
      internal_objects = []
      if !value.blank? && value.count.positive?
        value.each do |object|
          internal_object = ('DataCycleCore::' + storage_location.classify).constantize
            .find_by(id: object['id'])
          internal_objects.push(internal_object) unless internal_object.blank?
        end
      else
        return nil
      end

      internal_objects
    end

    def self.get_internal_template(storage_location, name)
      internal_template = ('DataCycleCore::' + storage_location.classify).constantize
        .find_by(template: true, template_name: name)

      return nil if internal_template.blank?

      internal_template
    end

    def self.get_object_params(storage_location, template_name)
      template = get_internal_template(storage_location, template_name)
      datahash = get_params_from_hash(template.schema)
      datahash
    end

    def self.create_internal_object(storage_location, template_name, object_params, current_user)
      object = ('DataCycleCore::' + storage_location.classify).constantize.new(object_params)

      template = get_internal_template(storage_location, template_name)
      object.schema = template.schema
      object.template_name = template.template_name
      object.save

      if !object_params[:datahash].nil?
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], object.schema)
        datahash['creator'] = current_user[:id]
        datahash['headline_external'] = datahash['headline']
      else
        return nil
      end

      datahash['permitted_creator'] = current_user.try(:role).try(:rank) == 3 ? [DataCycleCore::Classification.find_by(name: 'Markt Office').try(:id)] : [DataCycleCore::Classification.find_by(name: 'Team CM').try(:id)]

      object.set_data_hash(data_hash: datahash, current_user: current_user, prevent_history: true)

      # validate ?
      if object.save
        return object
      else
        return nil
      end
    end

    class << self
      private

      def get_params_from_hash(template_hash)
        temp_params = []

        template_hash['properties'].each do |key, value|
          orig_key = key
          key = 'value' if value['releasable']

          if value['type'] == 'object' && !value.dig('editor', 'type').nil?
            object_properties = get_internal_template(value['storage_location'], value['name'])
            key = { key.to_sym => get_params_from_hash(object_properties.schema) }
          elsif value['type'] == 'object' && !value['properties'].nil? && !value['properties'].empty?
            key = { key.to_sym => get_params_from_hash(value) }
          elsif value['type'] == 'classificationTreeLabel' || value['type'] == 'embeddedLinkArray'
            key = { key.to_sym => [] }
          else
            key = key.to_sym
          end

          key = { orig_key.to_sym => [key, 'release_id', 'release_comment'] } if value['releasable']

          temp_params.push(key)
        end

        temp_params
      end

      def flatten_recursive(datahash, template_hash)
        temp_datahash = {}

        datahash.each do |key, value|
          properties = template_hash['properties'][key]

          if value.is_a?(::Hash)

            if properties['type'] == 'object' && !properties.dig('editor', 'type').nil? && properties.dig('editor', 'type') == 'embeddedObject'
              object_properties = get_internal_template(properties['storage_location'], properties['name'])
              temp_value = []

              value.each_value do |object_value|
                temp_value.push(flatten_recursive(object_value, object_properties.schema))
              end

              value = temp_value

            elsif value['value'].is_a?(::Array)
              value['value'] = value['value'].reject(&:blank?)
            end
          elsif value.is_a?(::Array)
            value = value.reject(&:blank?).uniq
          elsif properties['type'] == 'number' && !properties['validations'].nil? && !properties['validations']['format'].nil? && properties['validations']['format'] == 'float'
            value = value.to_f
          elsif properties['type'] == 'number'
            value = value.to_i
          end

          temp_datahash[key] = value
        end

        temp_datahash
      end
    end
  end
end
