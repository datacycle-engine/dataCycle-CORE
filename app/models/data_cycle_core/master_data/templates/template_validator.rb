# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateValidator
        TRANSLATED_COLUMS = ['content', 'name', 'description', 'slug'].freeze

        attr_reader :errors

        def initialize(templates:)
          @templates = templates
          @template_header_contract = TemplateHeaderContract.new
          @template_property_contract = TemplatePropertyContract.new
          @errors = []
        end

        def valid?
          @errors.blank?
        end

        def validate
          return [] if @templates.blank?

          @templates.each do |set, templates|
            templates.each do |template|
              prefix = [set, template[:name]]
              result_header = @template_header_contract.call(template)
              merge_errors!(result_header, prefix + [:header])

              validate_properties!(template[:data], prefix)
              validate_translatable_embedded!(template, prefix)
              validate_property_names!(template.dig(:data, :properties), prefix)
            end
          end

          @errors
        end

        def merge_errors!(contract, prefix)
          contract.errors.each do |error|
            @errors.push("#{[*prefix, *error.path].join('.')} => #{error.text}")
          end
        end

        def translatable_properties?(properties)
          properties.each do |name, property|
            next if property[:type].in?([:key, :classification, :asset, :linked, :embedded])

            return true if property[:storage_location] == 'translated_value'
            return true if property[:storage_location] == 'column' && name.to_s.in?(TRANSLATED_COLUMS)
            return true if property.key?(:properties) && translatable_properties?(property.dig(:properties))
          end

          false
        end

        def validate_translatable_embedded!(template, prefix)
          template_list = @templates.values.flatten

          template.dig(:data, :properties).each do |key, value|
            next if value[:type] != 'embedded'

            embedded_template = template_list.find { |t| t[:name] == value[:template_name] }

            next if embedded_template.nil? || translatable_properties?(embedded_template.dig(:data, :properties))
            next if value[:translated]

            @errors.push("#{[*prefix, :properties, key].join('.')} => uses not translatable embedded (HINT: add ':translated: true' to make it work)")
          end
        end

        def validate_properties!(template, prefix)
          template[:properties].each do |key, definition|
            @template_property_contract.property_name = key
            result_property = @template_property_contract.call(definition)
            merge_errors!(result_property, prefix + [:properties, key])

            validate_properties!(definition, prefix + [:properties, key]) if definition.key?(:properties)

            @errors.push("#{[*prefix, :properties, key].join('.')} => must be underscored string") if key.to_s != key.to_s.underscore
          end
        end

        def validate_property_names!(properties, prefix)
          simple_objects = properties.select { |_, v| v['type'] == 'object' }
          return if simple_objects.blank?

          sub_keys = simple_objects.map { |_, v| v['properties'].keys }.flatten
          root_keys = properties.keys
          return if (root_keys & sub_keys).blank?

          @errors.push("#{[*prefix, :property_names].join('.')} => Simple Objects Error: keys #{root_keys & sub_keys} are not unique!")
        end
      end
    end
  end
end
