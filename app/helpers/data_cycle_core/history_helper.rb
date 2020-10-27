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
          t('history.created_at', locale: DataCycleCore.ui_language),
          l(content.created_at.in_time_zone, locale: DataCycleCore.ui_language),
          history_by_link(content.created_by_user),
          version_name_html(content)
        ].compact, ' ')
      end

      if content.updated_at.present? && content.updated_at.to_i != content.created_at.to_i
        data[:updated] = tag.span(safe_join([
          t('history.updated_at', locale: DataCycleCore.ui_language),
          l(content.updated_at.in_time_zone, locale: DataCycleCore.ui_language),
          history_by_link(content.updated_by_user),
          version_name_html(content)
        ].compact, ' '), title: content.histories.exists? ? nil : strip_tags(data[:created]).presence)
      end

      data
    end

    def history_by_link(user)
      link_text = t('terms.from', locale: DataCycleCore.ui_language)

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
      return nil unless item.version_name.present? && DataCycleCore::Feature::NamedVersion.enabled?

      version_name = []
      version_name.push(tag.i(class: 'fa fa-tag version-name has-tip', title: item.version_name))
      version_name.push(
        link_to(
          tag.i(class: 'fa fa-times alert-color'),
          remove_version_name_path(class_name: item.class.name, id: item.id),
          remote: true,
          class: 'remove-version-name-link',
          title: t('feature.named_version.remove_version_name', locale: DataCycleCore.ui_language),
          method: :patch,
          data: {
            confirm: t('feature.named_version.confirm_remove', locale: DataCycleCore.ui_language, name: item.version_name)
          }
        )
      )
      tag.span(safe_join(version_name.compact), class: 'named-version-container', id: "version-name-#{item.id}")
    end

    def history_dropdown_line(item, content, last_history_id, active_id)
      data = []

      if item.id == last_history_id && !item.created_by_user.nil?
        data.push(history_dropdown_link(item.created_by_user))
      else
        data.push(history_dropdown_link(item.updated_by_user))
      end

      I18n.with_locale(item.first_available_locale) do
        data.push(tag.span("(#{I18n.locale})", class: 'history-locale'))
        data.push(version_name_html(item))

        history_date = item.history_valid&.first
        data.push(tag.span(l(Time.zone.at(history_date), locale: DataCycleCore.ui_language, format: :history), class: 'history-time', title: l(Time.zone.at(history_date), locale: DataCycleCore.ui_language))) if history_date.present?
      end

      if can?(:history, content) && active_id != item.id
        data.push(
          tag.span(
            link_to(tag.i(class: 'fa fa-history', title: t('history.look_at_version', locale: DataCycleCore.ui_language)), history_thing_path(content, history_id: item.id, watch_list_id: @watch_list)),
            class: 'history-link'
          )
        )
      end

      tag.li(safe_join(data.compact), class: active_id == item.id ? 'active' : '')
    end
  end
end
