# frozen_string_literal: true

module DataCycleCore
  module HistoryHelper
    INDICATOR_CLASSES = {
      '+' => 'has-changes new',
      '-' => 'has-changes remove',
      '~' => 'has-changes edit'
    }.freeze

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
      diff.presence&.each do |mode|
        return INDICATOR_CLASSES[mode[0]] if mode[1].presence&.include?(value)
      end
      ''
    end

    def changes_mode(diff)
      return '' if diff.blank?
      if diff.is_a?(Hash) || diff.dig(0).is_a?(Array)
        INDICATOR_CLASSES['~']
      else
        INDICATOR_CLASSES[diff.dig(0)]
      end
    end

    def changes_by_value(diff, value)
      diff.presence&.each do |mode|
        return [[mode[0], value]] if mode[1].presence&.include?(value)
      end
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
      data = {}
      if content.created_at.present?
        data[:created] = safe_join([
          t('history.created_at', locale: active_ui_locale),
          l(content.created_at.in_time_zone, locale: active_ui_locale),
          history_by_link(content.created_by_user)
        ].compact, ' ')
      end

      if content.updated_at.present? && content.updated_at.to_i != content.created_at.to_i
        data[:updated] = tag.span(safe_join([
          t('history.updated_at', locale: active_ui_locale),
          l(content.updated_at.in_time_zone, locale: active_ui_locale),
          history_by_link(content.updated_by_user)
        ].compact, ' '), title: content.histories.exists? ? nil : strip_tags(data[:created]).presence)
      end

      data
    end

    def history_by_link(user)
      link_text = t('terms.from', locale: active_ui_locale)

      if user.nil?
        safe_join([link_text, tag.b('System')], ' ')
      else
        safe_join([link_text, tag.b(tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", title: user.full_name))], ' ')
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
        version_name.push(tag.i(class: 'fa fa-tag version-name has-tip', title: t('feature.named_version.version_name', name: item[:version_name], locale: active_ui_locale)))
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
      tag.span(safe_join(version_name.compact), class: "named-version-container#{' removable' if item[:can_remove_version_name]}", id: "version-name-#{item[:id]}")
    end

    def history_dropdown_line(content, item, watch_list_id, is_active = false, is_last = false)
      data = []

      data.push(history_dropdown_link(is_last && !item[:created_by_user].nil? ? item[:created_by_user] : item[:updated_by_user]))
      data.push(tag.span(item[:locale].presence&.then { |s| "(#{s})" }, class: 'history-locale'))

      history_date = is_last && item[:class_name] == 'DataCycleCore::Thing' ? item[:created_at] : item[:updated_at]
      data.push(tag.span(l(history_date.in_time_zone, locale: active_ui_locale, format: :history), class: 'history-time', title: l(history_date.in_time_zone, locale: active_ui_locale))) if history_date.present?

      data.push(version_name_html(item)) if DataCycleCore::Feature::NamedVersion.enabled?
      if can?(:history, content)
        data.push(
          tag.span(
            item[:class_name] == 'DataCycleCore::Thing::History' && !is_active ? link_to(tag.i(class: 'fa fa-history', title: t('history.look_at_version', locale: active_ui_locale)), history_thing_path(content, history_id: item[:id], watch_list_id: watch_list_id)) : nil,
            class: 'history-link'
          )
        )
      end

      tag.li(safe_join(data.compact), class: is_active ? 'active' : '')
    end

    def complete_history_list(content)
      history_entries = []
      if content.updated_at.present? && content.updated_at.to_i != content.created_at.to_i
        history_entries.push(map_to_history_entry(content))
        history_entries.concat(ordered_history_entries(content))
      end

      locales_without_history = content.translated_locales.difference(content.histories.translated_locales)
      history_entries.push(map_to_history_entry(content, locales_without_history, false)) if locales_without_history.any?

      history_entries
    end

    def ordered_history_entries(content)
      content.histories.includes(:translations, :created_by_user, :updated_by_user).map do |history|
        map_to_history_entry(history, history.translated_locales)
      end
    end

    def map_to_history_entry(item, locales = nil, include_version_name = true)
      I18n.with_locale(item.first_available_locale) do
        {
          id: item.id,
          created_by: item.created_by,
          updated_by: item.updated_by,
          created_at: item.created_at,
          updated_at: item.is_a?(DataCycleCore::Thing::History) ? item.history_valid&.first : item.updated_at,
          class_name: item.class.name,
          version_name: include_version_name ? item.version_name : nil,
          created_by_user: item.created_by_user,
          updated_by_user: item.updated_by_user,
          locale: Array.wrap(locales).join(', '),
          can_remove_version_name: DataCycleCore::Feature::NamedVersion.enabled? && can?(:remove_version_name, item)
        }
      end
    end
  end
end
