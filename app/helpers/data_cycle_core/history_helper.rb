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
                                     history_by_link(content.created_by_user)
                                   ], ' ')
      end

      if content.updated_at.present? && content.updated_at != content.created_at
        data[:updated] = tag.span(safe_join([
                                              t('history.updated_at', locale: DataCycleCore.ui_language),
                                              l(content.updated_at.in_time_zone, locale: DataCycleCore.ui_language),
                                              history_by_link(content.updated_by_user)
                                            ], ' '), title: strip_tags(data[:created]).presence)
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
  end
end
