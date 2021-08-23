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
      label_html = []

      label_html.push(
        tag.span(
          t('actions.finalize', locale: active_ui_locale),
          title: t('common.content_not_editable', locale: active_ui_locale),
          data: {
            tooltip: true
          }
        )
      )

      if I18n.exists?('finalize_agbs_html', locale: active_ui_locale)
        label_html.push(
          tag.span(
            safe_join(
              [
                "(#{t('actions.finalize_agbs_text', locale: active_ui_locale)} ",
                tag.i(class: 'fa fa-info-circle'),
                ')'
              ]
            ),
            title: t('finalize_agbs_html', locale: active_ui_locale),
            data: {
              tooltip: true,
              allow_html: true
            }
          )
        )

      end

      safe_join(label_html, ' ')
    end
  end
end
