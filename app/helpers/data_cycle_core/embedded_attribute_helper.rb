# frozen_string_literal: true

module DataCycleCore
  module EmbeddedAttributeHelper
    BADGE_TITLE_LIMIT = 10

    def embedded_attribute_value(content, object, key, definition, locale, translate, duplicated_content: false)
      return I18n.with_locale(locale) { object.default_value(key.attribute_name_from_key, current_user, {}) } if object.new_record? && !object.generic_template?
      return false if duplicated_content && DataCycleCore::Feature::ReusableEmbedded.reset_on_copy?(key)

      if translate && definition['type'] == 'string' && DataCycleCore::Feature['Translate']&.allowed?(content, I18n.locale, locale, current_user)
        source_locale = locale || object.first_available_locale
        translated_text = DataCycleCore::Feature['Translate'].translate_text({
          'text' => I18n.with_locale(source_locale) { object.try(key.to_sym) },
          'source_locale' => source_locale.to_s,
          'target_locale' => I18n.locale.to_s
        })

        return if translated_text.try(:error).present?

        translated_text['text']
      else
        I18n.with_locale(locale) { object.try(key.to_sym) }
      end
    end

    def embedded_editor_header(key:, content:, definition:, options: nil, **args)
      editable = attribute_editable?(key, definition, options, content)

      html = attribute_edit_label_tag(**args, key:, content:, definition:, options:, i18n_count: 2)
      html << render('data_cycle_core/contents/viewers/shared/accordion_toggle_buttons', button_type: 'children')
      html << tag.div(new_embedded_button(key:, content:, definition:, options:), class: 'new-embedded-button-wrapper') if editable

      tag.div(html, class: 'embedded-editor-header dc-sticky-bar')
    end

    # The plus button, as a dropdown once there is more than one entry: several templates, or the
    # entry "link existing content" (Feature::ReusableEmbedded), which opens an object browser over
    # the flagged embedded whose selection EmbeddedObject links instead of copying.
    def new_embedded_button(key:, content:, definition:, options:)
      id = "add_#{options&.dig(:prefix)}#{sanitize_to_id(key)}"
      reusable = DataCycleCore::Feature::ReusableEmbedded.reusable_templates(definition['template_name'])
      browser_id = "#{options&.dig(:prefix)}#{sanitize_to_id(key)}_reusable" if reusable.present?

      html = if browser_id || definition['template_name'].is_a?(Array)
               render('data_cycle_core/contents/editors/embedded/new_partials/new_content_button', id:, browser_id:, templates: embedded_templates_for_select(Array.wrap(definition['template_name'])))
             else
               tag.button(tag.i(class: 'fa fa-plus'), id:, type: 'button', class: 'button add-content-object', data: { template: definition['template_name'] })
             end

      html << render('data_cycle_core/contents/editors/embedded/new_partials/reusable_embedded_browser', key:, content:, options:, html_id: browser_id, definition: definition.merge('template_name' => reusable)) if browser_id

      html
    end

    ReusableUsage = Struct.new(:parent_count, :titles)

    # How many contents place a persisted embedded, and the first few titles the user may read.
    # Gated on the parent count as much as on the flag: a block that lost its flag stays shared and
    # still needs the unlink button. A copy (duplicated_content) is about to become a new record.
    #
    # @return [ReusableUsage, nil] nil when there is nothing to show
    def reusable_embedded_usage(object, duplicated_content: false)
      return if duplicated_content || object.new_record?

      parents = object.try(:reusable_parents)
      return if parents.nil?

      parent_count = parents.count
      return if parent_count < 2 && !object.reusable?

      titles = parents.includes(:translations).limit(BADGE_TITLE_LIMIT).select { |parent| can?(:show, parent) }.map(&:title)
      ReusableUsage.new(parent_count, titles)
    end

    def reusable_embedded_badge(usage)
      return if usage.nil?

      tooltip = t('embedded.reusable_usage', count: usage.parent_count, locale: active_ui_locale)
      tooltip += ": #{usage.titles.join(', ')}#{', …' if usage.parent_count > BADGE_TITLE_LIMIT}" if usage.titles.any?

      tag.span(
        tag.i(class: 'fa fa-link', aria_hidden: true) + usage.parent_count.to_s,
        class: 'reusable-embedded-badge',
        data: { dc_tooltip: tooltip }
      )
    end

    # :template_name: order in the data definition carries no meaning for the dropdown. Read from
    # the template cache: this renders per embedded attribute of the form, one query each otherwise.
    def embedded_templates_for_select(template_names)
      sort_templates_by_translated_name(template_names.filter_map { |t| DataCycleCore::ThingTemplate.cached_by_template_name(t)&.template_thing })
    end

    def embedded_viewer_html_classes(**_args)
      'detail-type embedded-viewer embedded-wrapper'
    end

    # return locales to be rendered inline for the given key, depending on the type of embedded (translatable or not)
    def force_render_locales_for_key(object, local_assigns = {})
      return local_assigns[:force_render_locales] if local_assigns.key?(:force_render_locales)

      content = contextual_content(local_assigns)
      key = local_assigns[:key]&.attribute_name_from_key

      return [] if content.translatable_property?(key)

      object.available_locales
    end

    # return locales that are allowed to be rendered for the given key, depending on the type of embedded (translatable or not)
    def allowed_embedded_locales_for_key(local_assigns = {})
      content = contextual_content(local_assigns)
      key = local_assigns[:key]&.attribute_name_from_key

      return [I18n.locale] if content.translatable_property?(key)
      return local_assigns[:allowed_locales]&.map(&:to_sym) if local_assigns.key?(:allowed_locales)

      I18n.available_locales
    end

    def parsed_allowed_locales(local_assigns = {})
      local_assigns.dig(:parameters, :allowed_locales)&.map(&:to_sym).presence ||
        I18n.available_locales
    end
  end
end
