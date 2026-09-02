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
          @object_property_contract = ObjectPropertyContract.new
          @existing_template_names = @templates.pluck(:name)
          @overlay_key = DataCycleCore.features.dig('overlay', 'attribute_keys')&.first
          @errors = []
        end

        def valid?
          @errors.blank?
        end

        def validate
          return [] if @templates.blank?

          @templates.each do |template|
            prefix = [template[:set], template[:name]]
            result_header = @template_header_contract.call(template)
            merge_errors!(result_header, prefix)

            validate_properties!(template[:data], prefix)
            validate_translatable_embedded!(template, prefix)
            validate_property_names!(template.dig(:data, :properties), prefix)
            validate_overlay_properties(template[:data], prefix)
            validate_schema_types!(template[:data], prefix)
            validate_locale_inheritance!(template[:data], prefix)
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

          belongs_to_templates = @templates.filter { |t| t.dig(:data, :features, :overlay, :allowed) && template[:name] == t.dig(:data, :properties, @overlay_key, 'template_name') }

          return if belongs_to_templates.blank?

          belongs_to_templates.each do |belongs_to_template|
            (template[:properties].keys - belongs_to_template.dig(:data, :properties).keys - ['dummy']).each do |key|
              @errors.push("#{[*prefix, :properties, key].join('.')} => property does not exist in original template (#{belongs_to_template[:name]})")
            end
          end
        end

        # `schema_types` is supplied by the meta_data mixin, and only for
        # non-embedded templates that define `schema_ancestors` (mirrors the
        # mixin's own `:condition:`). A template that meets those criteria yet
        # lacks the property never included the mixin, which silently breaks
        # SchemaType filtering (e.g. object-browser stored_filters).
        def validate_schema_types!(template, prefix)
          return if template.blank?
          return if template[:content_type] == 'embedded'
          return unless template.key?(:schema_ancestors)
          return if template[:properties]&.key?(:schema_types)

          @errors.push("#{[*prefix, :properties, :schema_types].join('.')} => missing (HINT: include the 'meta_data' mixin)")
        end

        # locale_inheritance creates translations for the content out of a link, which is only
        # coherent for a linked property this side writes, on a translatable, non-embedded template:
        # DataCycleCore::Feature::DataHash::LocaleInheritance skips every other case, silently,
        # wherever it is triggered from.
        def validate_locale_inheritance!(template, prefix)
          return if template.blank?

          inheriting = template[:properties]&.filter { |_, definition| definition.dig(:features, :locale_inheritance, :allowed) }
          return if inheriting.blank?

          inheriting.each do |key, definition|
            error_path = [*prefix, :properties, key, :features, :locale_inheritance].join('.')

            if definition[:type] != 'linked'
              @errors.push("#{error_path} => only inherits from a linked property (HINT: got ':type: #{definition[:type]}')")
            elsif definition[:link_direction] == 'inverse'
              @errors.push("#{error_path} => cannot inherit through an inverse link (HINT: it is written on the other side, so there is nothing to write in the new locale)")
            end
          end

          @errors.push("#{[*prefix, :content_type].join('.')} => locale_inheritance is not supported for embedded templates (HINT: an embedded content is translated through its parent)") if template[:content_type] == 'embedded'

          return if template.dig(:features, :translatable, :allowed)

          @errors.push("#{[*prefix, :features, :translatable].join('.')} => missing (HINT: locale_inheritance creates translations, add ':translatable: {:allowed: true}')")
        end

        def translatable_properties?(properties)
          properties.each do |name, property|
            next if property[:type].in?([:key, :classification, :asset, :linked, :embedded])

            return true if property[:storage_location] == 'translated_value'
            return true if property[:storage_location] == 'column' && name.to_s.in?(TRANSLATED_COLUMS)
            return true if property.key?(:properties) && translatable_properties?(property[:properties])
          end

          false
        end

        def validate_translatable_embedded!(template, prefix)
          template.dig(:data, :properties).each do |key, value|
            next if value[:type] != 'embedded'

            embedded_template = @templates.find { |t| t[:name] == value[:template_name] }

            next if embedded_template.nil? || translatable_properties?(embedded_template.dig(:data, :properties))
            next if value[:translated]

            @errors.push("#{[*prefix, :properties, key].join('.')} => uses not translatable embedded (HINT: add ':translated: true' to make it work)")
          end
        end

        def validate_properties!(template, prefix, contract = @template_property_contract)
          template[:properties].each do |key, definition|
            contract.property_name = key
            result_property = contract.call(definition)
            error_path = [*prefix, :data, :properties, key]
            merge_errors!(result_property, error_path)

            validate_properties!(definition, error_path, @object_property_contract) if definition.key?(:properties)

            validate_linked_template!(definition, error_path) if definition.key?(:template_name)

            validate_limited_by_linked!(definition, template[:properties], error_path)

            @errors.push("#{error_path.join('.')} => must be underscored") if key.to_s != key.to_s.underscore_blanks
          end
        end

        # `ui.edit.options.limited_by_linked` restricts an object browser to the
        # contents the current content is already linked to via the referenced
        # attribute(s). Those attributes must be non-editable (computed, virtual
        # or inverse links), so the candidate set is derived automatically and
        # not from another manually maintained field.
        def validate_limited_by_linked!(definition, properties, prefix)
          relations = Array.wrap(definition.dig(:ui, :edit, :options, :limited_by_linked)).compact_blank
          return if relations.blank?

          error_path = [*prefix, :ui, :edit, :options, :limited_by_linked].join('.')

          relations.each do |relation|
            referenced = properties[relation.to_sym] || properties[relation.to_s]

            if referenced.blank?
              @errors.push("#{error_path} => references unknown attribute '#{relation}'")
            elsif !non_editable_relation?(referenced)
              @errors.push("#{error_path} => '#{relation}' must be a non-editable attribute (computed, virtual or inverse link)")
            end
          end
        end

        def non_editable_relation?(property)
          (property[:compute] || property['compute']).present? ||
            (property[:virtual] || property['virtual']).present? ||
            (property[:link_direction] || property['link_direction']).to_s == 'inverse'
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
