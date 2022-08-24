# frozen_string_literal: true

module DataCycleCore
  module AttributeEditorHelper
    ATTRIBUTE_DATAHASH_PREFIX = '[datahash]'
    ATTRIBUTE_DATAHASH_REGEX = Regexp.new(/.*\K(#{Regexp.quote(ATTRIBUTE_DATAHASH_PREFIX)}|\[translations\]\[[^\]]*\])/)
    ATTRIBUTE_FIELD_PREFIX = "thing#{ATTRIBUTE_DATAHASH_PREFIX}"
    RENDER_EDITOR_ARGUMENTS = DataCycleCore::AttributeViewerHelper::RENDER_VIEWER_ARGUMENTS.deep_merge({
      parameters: { options: { edit_scope: 'edit' } },
      scope: :edit
    }).freeze

    DURATION_UNITS = {
      months: 12,
      days: 31,
      hours: 24,
      minutes: 60
    }.freeze

    def attribute_editable?(key, definition, options, content)
      @attribute_editable ||= Hash.new do |h, k|
        h[k] = can?(:update, DataCycleCore::DataAttribute.new(k[0], k[1], k[2], k[3], :update, k.dig(2, 'edit_scope')))
      end

      @attribute_editable[[key, definition, options, content]]
    end

    def attribute_editor_allowed(options)
      return if options.type?('slug') && options.parameters[:parent]&.embedded?
      return if options.definition['compute'].present?
      return render('data_cycle_core/contents/editors/attribute_group', options.render_params) if options.type?('attribute_group')

      return render_linked_viewer(**options.to_h.slice(:key, :definition, :value, :parameters, :content)) if options.type?('linked') && options.definition['link_direction'] == 'inverse'

      return unless can?(:edit, DataCycleCore::DataAttribute.new(
                                  options.key,
                                  options.definition,
                                  options.parameters[:options],
                                  options.content,
                                  options.scope,
                                  options.parameters.dig(:options, :edit_scope)
                                )) &&
                    (options.content.nil? || options.content&.allowed_feature_attribute?(options.key.attribute_name_from_key))

      return if options.type?('classification') && !DataCycleCore::ClassificationService.visible_classification_tree?(options.definition['tree_label'], options.scope.to_s)

      true
    end

    def render_attribute_editor(**args)
      options = DataCycleCore::AttributeViewerHelper::RenderMethodOptions.new(**args, defaults: RENDER_EDITOR_ARGUMENTS)

      options.key = Array.wrap(options.key.is_a?(String) ? options.key.attribute_name_from_key : options.key).map { |k| "[#{k}]" if k != 'properties' }.join.prepend(options.prefix.to_s)

      allowed = attribute_editor_allowed(options)
      return allowed unless allowed.is_a?(TrueClass)

      if (attribute_translatable?(*options.to_h.slice(:key, :definition, :content).values) && !options.parameters&.dig(:parent_translatable)) || object_has_translatable_attributes?(options.content, options.definition)
        render_translatable_attribute_editor(**options.to_h)
      else
        render_untranslatable_attribute_editor(**options.to_h)
      end
    end

    def render_specific_translatable_attribute_editor(**args)
      options = DataCycleCore::AttributeViewerHelper::RenderMethodOptions.new(**args, defaults: RENDER_EDITOR_ARGUMENTS)

      I18n.with_locale(options.locale) do
        content = options.parameters[:parent] || options.content

        if DataCycleCore::DataHashService.blank?(options.value)
          content.default_value(options.key.attribute_name_from_key, current_user) if content.is_a?(DataCycleCore::Thing) && (!content.persisted? || content.template)
          options.value = content.try(options.key.attribute_name_from_key)
        end

        allowed = attribute_editor_allowed(options)
        return allowed unless allowed.is_a?(TrueClass)

        render_untranslatable_attribute_editor options.to_h
      end
    end

    def render_translatable_attribute_editor(**args)
      options = DataCycleCore::AttributeViewerHelper::RenderMethodOptions.new(**args, defaults: RENDER_EDITOR_ARGUMENTS)

      render 'data_cycle_core/contents/editors/translatable_field', options.to_h
    end

    def render_untranslatable_attribute_editor(**args)
      options = DataCycleCore::AttributeViewerHelper::RenderMethodOptions.new(**args, defaults: RENDER_EDITOR_ARGUMENTS)

      partials = [
        options.definition&.dig('ui', options.parameters.dig(:options, :edit_scope), 'partial').presence,
        options.definition&.dig('ui', 'edit', 'partial').presence,
        "#{options.definition['type'].underscore_blanks}_#{options.key.attribute_name_from_key}",
        *feature_templates(options.key, options.definition, options.content),
        options.definition&.dig('ui', 'edit', 'type')&.underscore_blanks&.prepend(options.definition['type'].underscore_blanks, '_').presence,
        options.definition['type'].underscore_blanks.to_s
      ]
      partials.compact!
      partials.map! { |p| "data_cycle_core/contents/editors/#{p}" }

      options.parameters[:options][:readonly] = !attribute_editable?(options.key, options.definition, options.parameters[:options], options.content)

      render_first_existing_partial(partials, options.render_params)
    end

    def embedded_key_prefix(key, index)
      "#{key}[#{index}]#{ATTRIBUTE_DATAHASH_PREFIX}"
    end

    def attribute_editor_html_classes(key:, definition:, options:, parent: nil, **_args)
      html_classes = [
        'clearfix',
        'form-element',
        key.attribute_name_from_key,
        definition['type']&.underscore,
        definition.dig('ui', 'edit', 'options', 'class')&.underscore,
        options&.dig('class')
      ]

      html_classes.push('validation-container') if definition.key?('validations')
      html_classes.push('dc-quality-score') if definition.key?('quality_score')
      html_classes.push(definition.dig('ui', 'edit', 'type')&.underscore) if definition&.dig('ui', options[:edit_scope], 'partial').blank?
      html_classes.push('is-embedded-title') if parent&.embedded_title_property_name.present? && key.attribute_name_from_key == parent.embedded_title_property_name

      html_classes.compact_blank!
      html_classes.uniq!
      html_classes.join(' ')
    end

    def attribute_editor_data_attributes(key:, definition:, options:, content:, **_args)
      {
        label: translated_attribute_label(key, definition, content, options),
        key: key,
        id: "#{options&.dig(:prefix)}#{sanitize_to_id(key)}"
      }
    end
  end
end
