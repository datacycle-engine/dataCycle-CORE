# frozen_string_literal: true

module DataCycleCore
  module AttributeEditorHelper
    ATTRIBUTE_DATAHASH_PREFIX = '[datahash]'
    ATTRIBUTE_DATAHASH_REGEX = /.*\K(#{Regexp.quote(ATTRIBUTE_DATAHASH_PREFIX)}|\[translations\]\[[^\]]*\])/
    ATTRIBUTE_FIELD_PREFIX = "thing#{ATTRIBUTE_DATAHASH_PREFIX}".freeze
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

    def schedule_duration_values(duration)
      duration = DataCycleCore::Schedule.iso8601_duration_to_parts(duration)
      duration_hash = DURATION_UNITS.to_h { |k, v| [k, { max: v, value: duration[k] }] }
      duration_hash[:months][:value] = duration_hash[:months][:value].to_i + 12 * duration[:years] if duration.key?(:years)
      duration_hash
    end

    def attribute_editable?(key, definition, options, content)
      @attribute_editable ||= Hash.new do |h, k|
        h[k] = can?(:update, DataCycleCore::DataAttribute.new(*k, :update, k.dig(2, 'edit_scope')))
      end

      @attribute_editable[[key, definition, options, content]]
    end

    def attribute_editor_allowed(options)
      return render('data_cycle_core/contents/editors/attribute_group', options.render_params) if options.type?('attribute_group')
      return if options.type?('slug') && options.parameters[:parent]&.embedded?
      return if options.definition.key?('compute')
      return if options.definition.key?('virtual')

      if options.overlay_attribute?
        return unless options.render_overlay_attribute?

        options.add_overlay_properties!
      end

      options.add_has_overlay_options! if options.attribute_has_overlay?

      return unless can?(:edit, DataCycleCore::DataAttribute.new(
                                  options.key,
                                  options.definition,
                                  options.parameters[:options],
                                  options.content,
                                  options.scope,
                                  options.parameters.dig(:options, :edit_scope)
                                )) &&
                    (options.content.nil? || options.content&.allowed_feature_attribute?(options.key.attribute_name_from_key))

      return render_linked_viewer(**options.to_h.slice(:key, :definition, :value, :parameters, :content)) if options.type?('linked') && options.definition['link_direction'] == 'inverse'

      return if options.type?('classification') && !DataCycleCore::ClassificationService.visible_classification_tree?(options.definition['tree_label'], options.scope.to_s)

      true
    end

    def render_attribute_editor(**)
      options = DataCycleCore::AttributeViewerHelper::RenderMethodOptions.new(**, defaults: RENDER_EDITOR_ARGUMENTS)

      options.key = Array.wrap(options.key.is_a?(String) ? options.key.attribute_name_from_key : options.key).map { |k| "[#{k}]" if k != 'properties' }.join.prepend(options.prefix.to_s)

      allowed = attribute_editor_allowed(options)
      return allowed unless allowed.is_a?(TrueClass)

      if (attribute_translatable?(*options.to_h.slice(:key, :definition, :content).values) && !options.parameters&.dig(:parent_translatable)) || object_has_translatable_attributes?(options.content, options.definition)
        render_translatable_attribute_editor(options)
      else
        render_untranslatable_attribute_editor(options)
      end
    end

    def render_specific_translatable_attribute_editor(**)
      options = DataCycleCore::AttributeViewerHelper::RenderMethodOptions.new(**, defaults: RENDER_EDITOR_ARGUMENTS)

      I18n.with_locale(options.locale) do
        content = options.parameters[:parent] || options.content

        if DataCycleCore::DataHashService.blank?(options.value)
          content.default_value(options.key.attribute_name_from_key, current_user) if content.is_a?(DataCycleCore::Thing) && !content.generic_template? && (content.new_record? || content.available_locales.exclude?(I18n.locale))
          options.value = content.try(options.key.attribute_name_from_key)
        end

        allowed = attribute_editor_allowed(options)
        return allowed unless allowed.is_a?(TrueClass)

        render_untranslatable_attribute_editor(options)
      end
    end

    def render_translatable_attribute_editor(options)
      render 'data_cycle_core/contents/editors/translatable_field', **options.to_h
    end

    def render_untranslatable_attribute_editor(options)
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

    def attribute_editor_html_classes(key:, definition:, options:, content: nil, parent: nil, **_args)
      html_classes = [
        'clearfix',
        'form-element',
        key.attribute_name_from_key,
        definition['type']&.underscore,
        definition.dig('ui', 'edit', 'options', 'class')&.underscore,
        options&.dig('class')
      ]

      html_classes.push('disabled') unless attribute_editable?(key, definition, options, content)
      html_classes.push('validation-container') if definition.key?('validations')
      html_classes.push(definition.dig('ui', 'edit', 'type')&.underscore) if definition&.dig('ui', options[:edit_scope], 'partial').blank?
      html_classes.push('is-embedded-title') if parent.is_a?(DataCycleCore::Thing) && parent.embedded_title_property_name.present? && key.attribute_name_from_key == parent.embedded_title_property_name

      html_classes.compact_blank!
      html_classes.uniq!
      html_classes.join(' ')
    end

    def attribute_editor_data_attributes(key:, definition:, options:, content:, **_args)
      {
        label: translated_attribute_label(key, definition, content, options),
        key:,
        id: "#{options&.dig(:prefix)}#{sanitize_to_id(key)}"
      }.merge(definition.dig('ui', 'edit', 'data_attributes')&.symbolize_keys&.transform_values { |v| v.is_a?(::Array) || v.is_a?(::Hash) ? v.to_json : v } || {})
    end

    def attribute_group_container(key:, definition:, options:, content:, html_content:, **args)
      return if html_content.blank?
      return html_content if options&.dig('edit_scope') == 'bulk_edit'

      is_accordion = definition.dig('features', 'collapsible')
      group_title = attribute_group_title(contextual_content(key:, definition:, options:, content:, **args), key)
      group_classes = ['attribute-group', 'editor', key.attribute_name_from_key, definition['features']&.keys&.join(' ')]
      group_classes << 'accordion' if is_accordion
      group_classes << 'has-title' if group_title.present?

      accordion_classes = ['attribute-group-item']
      accordion_classes << 'accordion-item' if is_accordion
      accordion_classes << 'is-active' unless !is_accordion || definition.dig('features', 'collapsed')

      tag.div(class: group_classes.compact.join(' '), data: { allow_all_closed: true, accordion: is_accordion }) do
        tag.div(class: accordion_classes.compact.join(' '), data: { accordion_item: is_accordion }) do
          concat link_to_if(
            is_accordion,
            tag.span(group_title, class: 'attribute-group-title'),
            '#',
            class: "attribute-group-title-link #{'accordion-title' if is_accordion}"
          )
          concat tag.div(
            safe_join([
              group_title.present? && DataCycleCore::Feature::GeoKeyFigure.allowed_child_attribute_key?(content, definition) ? render('data_cycle_core/contents/editors/features/geo_key_figure_all') : nil
            ].compact),
            class: 'buttons'
          )
          concat tag.div(
            tag.div(html_content, class: 'attribute-group-content-element'),
            class: "attribute-group-content #{'accordion-content' if is_accordion}",
            data: { tab_content: is_accordion }
          )
        end
      end
    end

    def overlay_types(content, key, prop)
      label = translated_attribute_label(key, prop, content, {})

      check_boxes = [
        MasterData::Templates::Extensions::Overlay::BASE_OVERLAY_POSTFIX,
        MasterData::Templates::Extensions::Overlay::ADD_OVERLAY_POSTFIX
      ].index_with do |v|
        CollectionHelper::CheckBoxStruct.new(
          v.delete_prefix('_'),
          t("common.bulk_update.check_box_labels.#{v.delete_prefix('_')}_html", locale: active_ui_locale, data: label)
        )
      end

      type = prop.dig('ui', 'bulk_edit', 'partial') || prop.dig('ui', 'edit', 'partial') || prop.dig('ui', 'edit', 'type') || prop['type']
      versions = MasterData::Templates::Extensions::Overlay.allowed_postfixes_for_type(type)

      check_boxes.values_at(*versions)
    end
  end
end
