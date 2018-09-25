# frozen_string_literal: true

module DataCycleCore
  class DataHashService
    # TODO: refactor: class => module
    extend NormalizeService

    def self.flatten_datahash_value(datahash, template_hash, debug = false)
      datahash = flatten_recursive(datahash.to_h, template_hash)

      raise datahash.inspect if debug == true

      datahash
    end

    # TODO: see old embedded-editor
    # def self.get_internal_data(storage_location, value)
    #   internal_objects = []
    #   return nil if value.blank? || value.count.zero?
    #
    #   value.each do |object|
    #     internal_object = ('DataCycleCore::' + storage_location.classify).constantize
    #       .find_by(id: object['id'])
    #     internal_objects.push(internal_object) if internal_object.present?
    #   end
    #
    #   internal_objects
    # end

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

    def self.create_internal_object(storage_location, template_name, object_params, current_user, is_part_of = nil, source = nil)
      object = ('DataCycleCore::' + storage_location.classify).constantize.new(object_params)

      template = get_internal_template(storage_location, template_name)
      object.schema = template.schema
      object.template_name = template.template_name
      object.created_by = current_user.id
      object.is_part_of = is_part_of if is_part_of.present?
      object.save

      return nil if object_params[:datahash].nil?

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], object.schema)
      datahash['headline_external'] = datahash['headline']

      datahash['permitted_creator'] = current_user.try(:role).try(:rank) == 3 ? [DataCycleCore::Classification.find_by(name: 'Markt Office').try(:id)] : [DataCycleCore::Classification.find_by(name: 'Team CM').try(:id)]

      valid = object.set_data_hash(data_hash: datahash, current_user: current_user, prevent_history: true, source: source, new_content: true)

      return nil if valid[:error].present?
      object
    end

    class << self
      private

      def get_params_from_hash(template_hash)
        temp_params = []

        template_hash['properties'].each do |key, value|
          if value['type'] == 'embedded'
            object_properties = get_internal_template(value['linked_table'], value['template_name'])
            key = { key.to_sym => get_params_from_hash(object_properties.schema) }
          elsif value['type'] == 'object' && !value['properties'].nil? && !value['properties'].empty?
            key = { key.to_sym => get_params_from_hash(value) }
          elsif value['type'] == 'classification' || value['type'] == 'linked'
            key = { key.to_sym => [] }
          else
            key = key.to_sym
          end

          temp_params.push(key)
        end

        temp_params
      end

      def flatten_recursive(datahash, template_hash)
        temp_datahash = {}

        datahash.each do |key, value|
          properties = template_hash['properties'][key]

          if value.is_a?(::Hash)

            if properties['type'] == 'embedded'
              object_properties = get_internal_template(properties['linked_table'], properties['template_name'])
              temp_value = []

              value.each_value do |object_value|
                temp_value.push(flatten_recursive(object_value, object_properties.schema))
              end

              value = temp_value
            elsif properties['type'] == 'object'
              temp_value = {}

              value.each do |object_key, object_value|
                temp_value[object_key] = flatten_recursive({ object_key => object_value }, properties)[object_key]
              end

              value = temp_value
            elsif value['value'].is_a?(::Array)
              value['value'] = value['value'].reject(&:blank?)
            end
          elsif value.is_a?(::Array)
            value = value.reject(&:blank?).uniq
          elsif properties['type'] == 'number' && properties.dig('validations', 'format') == 'float'
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
