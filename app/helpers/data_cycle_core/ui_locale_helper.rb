# frozen_string_literal: true

module DataCycleCore
  module UiLocaleHelper
    def active_ui_locale
      current_user&.ui_locale || DataCycleCore.ui_locales.first
    rescue StandardError
      DataCycleCore.ui_locales.first
    end

    def available_locales_with_names
      @available_locales_with_names ||= Hash.new do |h, key|
        h[key] = I18n
          .t('locales', locale: key)
          .slice(*I18n.available_locales)
          .transform_values(&:capitalize)
          .sort_by { |_, v| v.to_s }
          .to_h
      end

      @available_locales_with_names[active_ui_locale]
    end

    def available_locales_with_all
      @available_locales_with_all ||= Hash.new do |h, key|
        if I18n.available_locales&.many?
          h[key] = available_locales_with_names.reverse_merge({ all: t('common.all', locale: active_ui_locale) })
        else
          h[key] = available_locales_with_names
        end
      end

      @available_locales_with_all[active_ui_locale]
    end

    def translated_attribute_label(key, definition, content, options)
      @translated_attribute_label ||= Hash.new do |h, k|
        h[k] = begin
          if I18n.exists?("attribute_labels.#{k[3]}.#{k[2]&.template_name}.#{k[0]}", locale: k[4])
            label = I18n.t("attribute_labels.#{k[3]}.#{k[2]&.template_name}.#{k[0]}", locale: k[4])
          elsif I18n.exists?("attribute_labels.#{k[2]&.template_name}.#{k[0]}", locale: k[4])
            label = I18n.t("attribute_labels.#{k[2]&.template_name}.#{k[0]}", locale: k[4])
          elsif I18n.exists?("attribute_labels.#{k[3]}.#{k[0]}", locale: k[4])
            label = I18n.t("attribute_labels.#{k[3]}.#{k[0]}", locale: k[4])
          elsif I18n.exists?("attribute_labels.#{k[0]}", locale: k[4])
            label = I18n.t("attribute_labels.#{k[0]}", locale: k[4])
          elsif k[1].present?
            label = k[1].dig('ui', k[3].to_s, 'label') || k[1]['label']
          else
            label = k[0].titleize
          end

          label += " (#{I18n.locale})" if attribute_translatable?(k[0], k[1], k[2])

          label
        end
      end

      @translated_attribute_label[
        [
          key.attribute_name_from_key,
          definition,
          content,
          options&.dig(:ui_scope),
          active_ui_locale
        ]
      ]
    end

    def object_has_translatable_attributes?(content, definition)
      return unless definition&.dig('type') == 'object'

      definition['properties']&.any? { |k, v| attribute_translatable?(k, v, content) }
    end

    def attribute_translatable?(key, definition, content)
      I18n.available_locales.many? &&
        content&.translatable? &&
        (
          (
            content&.translatable_property?(key.attribute_name_from_key, definition) &&
            definition&.dig('type') != 'object'
          ) ||
          (
            definition&.dig('type') == 'embedded' &&
            !definition&.dig('translated')
          )
        )
    end

    def attribute_viewer_label_tag(key, definition, content, options)
      label_html = ActionView::OutputBuffer.new(tag.span(translated_attribute_label(key, definition, content, options), class: 'attribute-label-text'))

      label_html.prepend(tag.i(class: 'fa fa-language translatable-attribute-icon')) if attribute_translatable?(key, definition, content)
      label_html.prepend(tag.i(class: "dc-type-icon property-icon key-#{key.attribute_name_from_key} type-#{definition&.dig('ui', 'edit', 'type') || definition&.dig('type')}"))

      tag.span label_html, class: 'detail-label'
    end

    def attribute_edit_label_tag(key:, definition:, content:, options:, **args)
      label_html = ActionView::OutputBuffer.new(tag.span(translated_attribute_label(key, definition, content, options), class: 'attribute-label-text'))

      label_html.prepend(tag.i(class: 'fa fa-language translatable-attribute-icon')) if attribute_translatable?(key, definition, content)
      label_html.prepend(tag.i(class: "dc-type-icon property-icon key-#{key.attribute_name_from_key} type-#{definition&.dig('ui', 'edit', 'type') || definition&.dig('type')}"))
      label_html.prepend(tag.i(class: 'fa fa-ban', aria_hidden: true)) unless attribute_editable?(key, definition, options, content)
      label_html << render('data_cycle_core/contents/helper_text', key: key, content: contextual_content({ content: content }.merge(args.slice(:parent))), definition: definition)

      label_tag "#{options&.dig(:prefix)}#{sanitize_to_id(key)}", label_html, class: 'attribute-edit-label'
    end
  end
end
