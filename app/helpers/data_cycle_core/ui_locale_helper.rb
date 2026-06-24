# frozen_string_literal: true

module DataCycleCore
  module UiLocaleHelper
    def active_ui_locale
      return @active_ui_locale if defined?(@active_ui_locale)

      @active_ui_locale = current_user&.ui_locale || DataCycleCore.ui_locales.first
    rescue StandardError
      @active_ui_locale = DataCycleCore.ui_locales.first
    end

    def i18n_digest
      I18n.backend.version_digest(active_ui_locale)
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
        h[key] = if I18n.available_locales&.many?
                   available_locales_with_names.reverse_merge({ all: t('common.all', locale: active_ui_locale) })
                 else
                   available_locales_with_names
                 end
      end

      @available_locales_with_all[active_ui_locale]
    end

    def translated_attribute_label(key, definition, content, options = {}, count = 1)
      DataCycleCore::Thing.human_attribute_name(key.attribute_name_from_key.to_s, (options || {}).merge({ base: content, count:, definition:, locale: active_ui_locale }))
    end

    def object_has_translatable_attributes?(content, definition)
      return false unless definition&.dig('type') == 'object'

      definition['properties']&.any? { |k, v| attribute_translatable?(k, v, content) }
    end

    def attribute_translatable?(key, definition, content)
      content&.attribute_translatable?(key.attribute_name_from_key, definition)
    end

    def concept_tag(concept, additional_classes = '')
      tag.span(
        concept.internal_name,
        class: "tag #{additional_classes} #{classification_path_classes(concept)}".squish,
        style: classification_style(concept),
        data: { dc_tooltip: classification_tooltip(concept) }
      )
    end

    def attribute_type_icon(content, key, definition, type = 'show')
      classlist = ['dc-type-icon', 'property-icon']
      classlist << "key-#{key.attribute_name_from_key}" if key.present?

      if definition&.dig('type').present?
        classlist << "type-#{definition['type']}"
        classlist << "type-#{definition['type']}-#{definition.dig('ui', type.to_s, 'type')}" if definition&.dig('ui', type.to_s, 'type').present?
      end

      tag.i(class: classlist.join(' '), data: { dc_tooltip: attribute_type_tooltip(content, key, definition) })
    end

    def attribute_type_tooltip(content, key, definition)
      attr_path = key.attribute_path_from_key if key.present?
      internal_name = attr_path&.last
      internal_name = 'mapped concept' if key.blank? && definition&.dig('type') == 'classification'
      dc_tooltip = nil

      if attr_path.present? && content.respond_to?(:api_name_for) &&
         (definition.dig('features', 'overlay').present? || api_definition(definition, '4', 'api')['disabled'] != true)
        dc_tooltip = content.api_name_for(attr_path, definition).to_s
      elsif attr_path.blank? && definition&.dig('type') == 'classification' && DataCycleCore::ClassificationService.visible_classification_tree?(definition['tree_label'], 'api')
        dc_tooltip = 'dc:classification'
      end

      if can?(:show_internal_name, :attribute) && dc_tooltip.present?
        dc_tooltip = safe_join(
          [
            safe_join([tag.b("#{t('common.api_identifier', locale: active_ui_locale)}:"), dc_tooltip], ' '),
            safe_join([tag.b("#{t('common.internal_identifier', locale: active_ui_locale)}:"), internal_name], ' ')
          ], tag.br
        )
      elsif can?(:show_internal_name, :attribute)
        dc_tooltip = safe_join([tag.b("#{t('common.internal_identifier', locale: active_ui_locale)}:"), internal_name], ' ')
      end

      dc_tooltip
    end

    def attribute_viewer_label_tag(key:, definition:, content:, options: nil, accordion_controls: false, i18n_count: 1, **args, &block)
      parent = contextual_content({ content: }.merge(args.slice(:parent)))
      parent_thing = parent.is_a?(DataCycleCore::Thing) ? parent : content

      label_html = ActionView::OutputBuffer.new
      label_html << attribute_type_icon(parent_thing, key, definition)
      label_html << tag.i(class: 'fa fa-language translatable-attribute-icon') if attribute_translatable?(key, definition, parent)
      label_html << tag.span(translated_attribute_label(key, definition, parent, options, i18n_count), class: 'attribute-label-text', title: translated_attribute_label(key, definition, parent, options, i18n_count))
      label_html << thing_info_icon(parent, key) # info texts without required marker
      label_html << render('data_cycle_core/contents/content_score', key:, content: parent, definition:) if definition.key?('content_score')
      label_html << render('data_cycle_core/contents/viewers/shared/accordion_toggle_buttons', button_type: 'children') if accordion_controls
      label_html << tag.span(tag.i(class: 'fa fa-clipboard'), class: 'copy-to-clipboard', data: { value: options[:copy_to_clipboard], dc_tooltip: t('actions.copy_to_clipboard', locale: active_ui_locale) }) if options&.dig(:copy_to_clipboard).present?
      label_html << capture(&block) if block

      tag.span label_html, class: 'detail-label'
    end

    def attribute_edit_label_tag(key:, definition:, content:, options:, html_classes: nil, i18n_count: 1, **args)
      parent = contextual_content({ content: }.merge(args.slice(:parent)))
      parent_thing = parent.is_a?(DataCycleCore::Thing) ? parent : content

      label_html = ActionView::OutputBuffer.new
      label_html << tag.i(class: 'fa fa-ban', aria_hidden: true) unless attribute_editable?(key, definition, options, content)
      label_html << attribute_type_icon(parent_thing, key, definition, 'edit')
      label_html << tag.i(class: 'fa fa-language translatable-attribute-icon') if attribute_translatable?(key, definition, parent)
      label_html << tag.span(translated_attribute_label(key, definition, parent, options, i18n_count), class: 'attribute-label-text', title: translated_attribute_label(key, definition, parent, options, i18n_count))
      label_html << render('data_cycle_core/contents/helper_text', key:, content: parent, definition:)
      label_html << render('data_cycle_core/contents/content_score', key:, content: parent, definition:) if definition.key?('content_score')
      label_html << yield_content!(:additional_label_content) if content_for?(:additional_label_content)

      label_tag "#{options&.dig(:prefix)}#{sanitize_to_id(key)}", label_html, class: "attribute-edit-label #{html_classes}".strip
    end

    def content_score_tooltip(content, definition)
      tooltip_html = [
        tag.div(safe_join([
                            t('feature.content_score.tooltip.title', locale: active_ui_locale),
                            tag.span(class: 'tooltip-content-score')
                          ]), class: 'title')
      ]
      cc_module = DataCycleCore::ModuleService.load_module(definition.dig('content_score', 'module').classify, 'Utility::ContentScore')
      tooltip_description = cc_module.try(:to_tooltip, content, definition, active_ui_locale)
      tooltip_html.push(tooltip_description) if tooltip_description.present?
      tag.div(tooltip_html.join, class: "content-score-tooltip #{'with-description' if tooltip_html.size > 1}")
    end

    def content_score_tooltip_string(content, definition)
      cc_module = DataCycleCore::ModuleService.load_module(definition.dig('content_score', 'module').classify, 'Utility::ContentScore')
      tooltip = cc_module.try(:to_tooltip, content, definition, active_ui_locale)

      return if tooltip.blank?

      tooltip = Array.wrap(tooltip)
      tooltip.each do |s|
        content_score_tooltip_string_helper(s)
      end
      tooltip.join
    end

    def content_score_tooltip_string_helper(s)
      s.gsub!(/\s*(<li[^>]*>)\s*/i, '* ')
      s.gsub!(%r{</li>\s*(?!\n)}i, "\n")
      s.gsub!(%r{</p>}i, "\n")
      s.gsub!(%r{<br[/ ]*>}i, "\n")
      s.gsub!(%r{</div>}i, "\n")
      s.gsub!(/<ul>/i, "\n")
      s.gsub!(%r{</ul>}i, '')
      s.gsub!(/<b>/i, '')
      s.gsub!(%r{</b>}i, '')
      s.strip_tags.strip
    end

    def thing_content_score_class(content)
      'dc-content-score' if content.respond_to?(:internal_content_score)
    end

    def thing_content_score(content)
      return unless content.respond_to?(:internal_content_score)

      content_score = content.internal_content_score.to_f.round

      tag.div(tag.span(class: 'content-score-icon') + tag.span(content_score, class: 'content-score-text'),
              class: 'thing-content-score',
              data: {
                dc_tooltip: t('feature.content_score.tooltip.title', locale: active_ui_locale) +
                  tag.span(t('feature.content_score.tooltip_score', score: content_score), class: 'tooltip-content-score')
              })
    end

    def thing_helper_text(content, key)
      return unless content.is_a?(DataCycleCore::Thing)

      content.translated_helper_text(key, active_ui_locale)
    end

    def thing_info_icon(content, key)
      helper_text = thing_helper_text(content, key)

      return if helper_text.blank?

      tag.i(class: 'fa fa-info-circle', data: { dc_tooltip: helper_text })
    end

    def collection_model_name_human(count: 1)
      t(
        'filter.relation_filter.placeholder.collection_or_stored_filter',
        collection: DataCycleCore::WatchList.model_name.human(count:, locale: active_ui_locale),
        stored_filter: DataCycleCore::StoredFilter.model_name.human(count:, locale: active_ui_locale),
        locale: active_ui_locale
      )
    end
  end
end
