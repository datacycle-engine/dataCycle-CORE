# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateValidator
        TRANSLATED_COLUMS = ['content', 'slug'].freeze

        attr_reader :errors

        def initialize(templates:)
          @templates = templates
          @template_header_contract = TemplateHeaderContract.new
          @template_property_contract = TemplatePropertyContract.new
          @all_templates = @templates.values.flatten
          @existing_template_names = @all_templates.pluck(:name)
          @overlay_key = DataCycleCore.features.dig('overlay', 'attribute_keys')&.first
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
              validate_overlay_properties(template[:data], prefix)
            end
          end

          @errors
        end

        def merge_errors!(contract, prefix)
          contract.errors.each do |error|
            @errors.push("#{[*prefix, *error.path].compact.join('.')} => #{error}")
          end
        end

        def validate_overlay_properties(template, prefix)
          return if @overlay_key.blank?

          belongs_to_templates = @all_templates.filter { |t| t.dig(:data, :features, :overlay, :allowed) && template[:name] == t.dig(:data, :properties, @overlay_key, 'template_name') }

          return if belongs_to_templates.blank?

          belongs_to_templates.each do |belongs_to_template|
            (template[:properties].keys - belongs_to_template.dig(:data, :properties).keys - ['dummy']).each do |key|
              @errors.push("#{[*prefix, :properties, key].join('.')} => property does not exist in original template (#{belongs_to_template[:name]})")
            end
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

            if definition.key?(:properties)
              @template_property_contract.nested_property = true
              validate_properties!(definition, prefix + [:properties, key]) if definition.key?(:properties)
              @template_property_contract.nested_property = false
            end

            validate_linked_template!(definition, prefix + [:properties, key]) if definition.key?(:template_name)

            @errors.push("#{[*prefix, :properties, key].join('.')} => must be underscored string") if key.to_s != key.to_s.underscore
          end
        end

        def validate_linked_template!(definition, prefix)
          Array.wrap(definition[:template_name]).each do |key|
            next if @existing_template_names.include?(key)

            @errors.push("#{[*prefix, :template_name].join('.')} => template for '#{key}' missing!")
          end
        end

        def validate_property_names!(properties, prefix)
          simple_objects = properties.select { |_, v| v['type'] == 'object' }
          return if simple_objects.blank?

          sub_keys = simple_objects.map { |_, v| v['properties'].keys }.flatten
          root_keys = properties.keys
          return unless root_keys.intersect?(sub_keys)

          @errors.push("#{[*prefix, :property_names].join('.')} => Simple Objects Error: Keys (#{(root_keys & sub_keys).join(', ')}) are not unique!")
        end
      end
    end
  end
end
