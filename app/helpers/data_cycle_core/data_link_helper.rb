# frozen_string_literal: true

module DataCycleCore
  module DataLinkHelper
    def data_link_modes(content)
      modes = [OpenStruct.new(type: :read)]

      modes.push(OpenStruct.new(type: :write)) if can?(:create_editable_links, DataCycleCore::DataLink) &&
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
  end
end
