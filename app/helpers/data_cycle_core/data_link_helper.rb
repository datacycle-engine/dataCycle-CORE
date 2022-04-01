# frozen_string_literal: true

module DataCycleCore
  module DataLinkHelper
    def data_link_modes(content)
      modes = [OpenStruct.new(type: :read)]

      modes.push(OpenStruct.new(type: :write)) if can?(:create_editable_links, DataCycleCore::DataLink) &&
                                                  !content.is_a?(DataCycleCore::StoredFilter) &&
                                                  (
                                                    (
                                                      content.is_a?(DataCycleCore::WatchList) &&
                                                      content.try(:things)&.all? { |thing| can?(:edit, thing) } &&
                                                      can?(:add_item, content)
                                                    ) ||
                                                    can?(:edit, content)
                                                  )

      modes.unshift(OpenStruct.new(type: :download)) if (
        content.is_a?(DataCycleCore::WatchList) && can?(:download_zip, content)
      ) || (
        content.is_a?(DataCycleCore::Thing) && can?(:download, content)
      )

      modes
    end

    def finalize_agbs_label
      unless I18n.exists?('finalize_agbs_html', locale: active_ui_locale)
        return tag.span(
          t('actions.finalize', locale: active_ui_locale),
          data: {
            dc_tooltip: t('common.content_not_editable', locale: active_ui_locale)
          }
        )
      end

      t(
        'actions.finalize_combined_html',
        locale: active_ui_locale,
        finalize: tag.span(
          t('actions.finalize', locale: active_ui_locale),
          data: {
            dc_tooltip: t('common.content_not_editable', locale: active_ui_locale)
          }
        ),
        agbs: tag.span(
          t('actions.finalize_agbs_text', locale: active_ui_locale),
          data: {
            dc_tooltip: t('finalize_agbs_html', locale: active_ui_locale)
          }
        )
      )
    end

    def terms_of_use_label
      terms_link_html = I18n.t('common.download.confirmation.terms_of_use_link_text', locale: active_ui_locale)

      if DataCycleCore::Feature::Download.configuration.dig('confirmation', 'terms_of_use_url').present?
        terms_link_html = link_to(
          terms_link_html,
          DataCycleCore::Feature::Download.configuration.dig('confirmation', 'terms_of_use_url'),
          target: :_blank, rel: :noopener
        )
      elsif I18n.exists?('common.download.confirmation.terms_of_use_html')
        terms_link_html = tag.span(
          terms_link_html,
          data: {
            dc_tooltip: I18n.t('common.download.confirmation.terms_of_use_html', locale: active_ui_locale)
          }
        )
      end

      ActionView::OutputBuffer.new(
        I18n.t('common.download.confirmation.terms_of_use_link_html', link: terms_link_html, locale: active_ui_locale)
      )
    end

    def download_item_type(data_link)
      if data_link.item.is_a?(DataCycleCore::Thing)
        item_type = data_link.item.translated_template_name(active_ui_locale)
        item_title = I18n.with_locale(data_link.item.first_available_locale) { data_link.item.try(:title) }
      else
        item_type = data_link.item.model_name.human(count: 1, locale: active_ui_locale)
        item_title = data_link.item.try(:name)
      end

      tag.span("#{item_type}: ", class: 'item-type') +
        tag.span(item_title, class: 'item-title', data: { dc_tooltip: item_title })
    end
  end
end
