# frozen_string_literal: true

module DataCycleCore
  module HistoryHelper
    INDICATOR_CLASSES = { '+' => 'has-changes new', '-' => 'has-changes remove', '~' => 'has-changes edit' }.freeze

    def attribute_changes(diff, key)
      return nil if diff.blank?
      item_path_array = key.split(/[\[\]]+/)

      # diff.dig(*item_path_array)
      save_navigate(diff, item_path_array)
    end

    def save_navigate(diff, item_path)
      data = diff
      item_path.each do |item|
        if data.is_a?(::Hash)
          data = data&.dig(item)
        else
          data = nil
          break
        end
      end
      data
    end

    def changes_class(diff, value)
      diff.presence&.each { |mode| return INDICATOR_CLASSES[mode[0]] if mode[1].presence&.include?(value) }
      ''
    end

    def changes_mode(diff)
      return '' if diff.blank?
      diff.is_a?(Hash) || diff.dig(0).is_a?(Array) ? INDICATOR_CLASSES['~'] : INDICATOR_CLASSES[diff.dig(0)]
    end

    def changes_by_value(diff, value)
      diff.presence&.each { |mode| return [[mode[0], value]] if mode[1].presence&.include?(value) }
      nil
    end

    def changes_by_mode(diff, mode)
      diff.presence&.select { |v| v[0] == mode }&.dig(0, 1) || []
    end

    def change_by_mode(diff, mode)
      return [] if diff&.dig(0) != mode
      diff[1]
    end

    def new_relations(diff, table)
      "data_cycle_core/#{table}".classify.constantize.where(id: changes_by_mode(diff, '+'))
    end

    def new_relation(diff, table)
      "data_cycle_core/#{table}".classify.constantize.where(id: change_by_mode(diff, '+'))
    end

    def visible_content_date(content)
      type = 'created'
      type = 'updated' if content.histories.exists? ||
                          (content.updated_at.present? && content.updated_at.to_i != content.created_at.to_i)

      return nil if (date = content.try("#{type}_at")).blank?

      date_string =
        safe_join(
          [
            t(
              "history.#{type}_at_html",
              locale: active_ui_locale,
              language: content.last_updated_locale,
              date: l(date.in_time_zone, locale: active_ui_locale, format: :history)
            ),
            history_by_link(content.try("#{type}_by_user"))
          ].compact,
          ' '
        )

      title_string =
        strip_tags(
          safe_join(
            [
              t(
                'history.created_at_html',
                locale: active_ui_locale,
                date: l(content.created_at.in_time_zone, locale: active_ui_locale)
              ),
              history_by_link(content.created_by_user)
            ].compact,
            ' '
          )
        )

      tag.span(date_string, title: title_string)
    end

    def history_by_link(user)
      link_text = t('terms.from', locale: active_ui_locale)

      if user.nil?
        safe_join([link_text, tag.b('System')], ' ')
      else
        safe_join(
          [
            link_text,
            tag.b(tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", title: user.full_name))
          ],
          ' '
        )
      end
    end

    def history_dropdown_link(user = nil)
      if user.nil?
        tag.span('System', class: 'email-link')
      else
        tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", title: user.full_name)
      end
    end

    def version_name_html(item)
      version_name = []
      if item[:version_name].present?
        version_name.push(
          tag.i(
            class: 'fa fa-tag version-name has-tip copy-to-clipboard',
            title: t('feature.named_version.version_name', name: item[:version_name], locale: active_ui_locale),
            data: {
              value: item[:version_name]
            }
          )
        )
        if item[:can_remove_version_name]
          version_name.push(
            link_to(
              tag.i(class: 'fa fa-times alert-color'),
              remove_version_name_path(class_name: item[:class_name], id: item[:id]),
              remote: true,
              class: 'remove-version-name-link',
              title: t('feature.named_version.remove_version_name', locale: active_ui_locale),
              method: :patch,
              data: {
                confirm: t('feature.named_version.confirm_remove', locale: active_ui_locale, name: item[:version_name])
              }
            )
          )
        end
      end
      tag.span(
        safe_join(version_name.compact),
        class: "named-version-container#{' removable' if item[:can_remove_version_name]}",
        id: "version-name-#{item[:id]}"
      )
    end

    def history_dropdown_line(content, item, watch_list_id, is_active = false)
      data = []

      data.push(history_dropdown_link(item[:updated_by_user]))
      data.push(tag.span(item[:locale].presence&.then { |s| "(#{s})" }, class: 'history-locale'))

      if item[:updated_at].present?
        data.push(
          tag.span(
            l(item[:updated_at].in_time_zone, locale: active_ui_locale, format: :history),
            class: 'history-time',
            title: l(item[:updated_at].in_time_zone, locale: active_ui_locale)
          )
        )
      end

      data.push(version_name_html(item)) if DataCycleCore::Feature::NamedVersion.enabled?

      history_link =
        tag.span(class: 'history-link') do
          if item.key?(:icon)
            item[:icon]
          elsif can?(:history, content) && item[:class_name] == 'DataCycleCore::Thing::History'
            link_to_unless is_active,
                           tag.i(class: 'fa fa-history', title: t('history.look_at_version', locale: active_ui_locale)),
                           history_thing_path(content, history_id: item[:id], watch_list_id: watch_list_id)
          end
        end

      data.push(history_link)

      tag.li(safe_join(data.compact), class: is_active ? 'active' : '')
    end

    def complete_history_list(content)
      history_entries = []

      return history_entries if content.nil?

      if content.histories.exists? ||
         (content.updated_at.present? && content.updated_at.to_i != content.created_at.to_i)
        history_entries.push(
          map_to_history_entry(item: content, locales: content.last_updated_locale).merge(
            icon:
              tag.i(
                class: 'fa fa-clock-o history-active-version-icon',
                title: t('history.active_version', locale: active_ui_locale)
              )
          )
        )

        history_entries.concat(ordered_history_entries(content))
      end

      created_locales = content
        .translations
        .where('thing_translations.created_at <= ?', content.created_at&.+(10.seconds))
        .pluck(:locale)

      content.translations.where.not(locale: content.histories.translated_locales + created_locales + [content.last_updated_locale]).each do |created_translation|
        history_entries.push({
          id: content.id,
          class_name: content.class.name,
          updated_at: [created_translation.created_at, created_translation.updated_at - 1.second, content.updated_at - 1.second].min,
          locale: created_translation.locale,
          can_remove_version_name: false
        }.merge(
          icon: tag.i(class: 'fa fa-plus history-created-icon', title: t('history.created', locale: active_ui_locale))
        ))
      end

      history_entries.push(
        map_to_history_entry(
          item: content,
          locales: created_locales,
          attribute_type: :created,
          include_version_name: false
        ).merge(
          icon: tag.i(class: 'fa fa-plus history-created-icon', title: t('history.created', locale: active_ui_locale))
        )
      )

      history_entries.sort! { |a, b| b[:updated_at].to_i - a[:updated_at].to_i }

      history_entries
    end

    def ordered_history_entries(content)
      content
        .histories
        .includes(:translations, :updated_by_user)
        .map { |history| map_to_history_entry(item: history, locales: history.translated_locales) }
    end

    def map_to_history_entry(item:, locales: nil, attribute_type: :updated, include_version_name: true)
      I18n.with_locale(item.first_available_locale) do
        {
          id: item.id,
          updated_by: item.try("#{attribute_type}_by"),
          updated_at: item.try(:history_valid)&.first || item.try("#{attribute_type}_at"),
          class_name: item.class.name,
          version_name: include_version_name ? item.version_name : nil,
          updated_by_user: item.try("#{attribute_type}_by_user"),
          locale: Array.wrap(locales).join(', '),
          can_remove_version_name: DataCycleCore::Feature::NamedVersion.enabled? && can?(:remove_version_name, item)
        }
      end
    end

    def history_version_html(content)
      date = content.try(:history_valid)&.first || content.try(:updated_at)

      history_html = ActionView::OutputBuffer.new
      history_html << t('history.updated_at_html', locale: active_ui_locale, language: content.last_updated_locale || content.first_available_locale, date: l(date, locale: active_ui_locale, format: :history)) if date.present?
      history_html << ' '
      history_html << history_by_link(content.updated_by_user)

      history_html
    end
  end
end
