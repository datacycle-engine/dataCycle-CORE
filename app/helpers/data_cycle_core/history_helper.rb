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
      return nil unless item['version_name'].present? && DataCycleCore::Feature::NamedVersion.enabled?

      version_name = []
      version_name.push(tag.i(class: 'fa fa-tag version-name has-tip', title: item['version_name']))
      version_name.push(
        link_to(
          tag.i(class: 'fa fa-times alert-color'),
          remove_version_name_path(class_name: item['class_name'], id: item['id']),
          remote: true,
          class: 'remove-version-name-link',
          title: t('feature.named_version.remove_version_name', locale: DataCycleCore.ui_language),
          method: :patch,
          data: {
            confirm: t('feature.named_version.confirm_remove', locale: DataCycleCore.ui_language, name: item['version_name'])
          }
        )
      )
      tag.span(safe_join(version_name.compact), class: 'named-version-container', id: "version-name-#{item['id']}")
    end

    def history_dropdown_line(content, entry, watch_list_id, is_active = false, is_last = false)
      data = []

      data.push(history_dropdown_link(is_last && !entry['created_by_user'].nil? ? entry['created_by_user'] : entry['updated_by_user']))

      data.push(tag.span("(#{entry['locale']})", class: 'history-locale')) if entry['locale'].present?
      data.push(version_name_html(entry))

      history_date = is_last && entry['class_name'] == 'DataCycleCore::Thing' ? entry['created_at'] : entry['updated_at']

      data.push(tag.span(l(history_date.in_time_zone, locale: DataCycleCore.ui_language, format: :history), class: 'history-time', title: l(history_date.in_time_zone, locale: DataCycleCore.ui_language))) if history_date.present?

      if can?(:history, content) && !is_active
        data.push(
          tag.span(
            entry['class_name'] == 'DataCycleCore::Thing::History' ? link_to(tag.i(class: 'fa fa-history', title: t('history.look_at_version', locale: DataCycleCore.ui_language)), history_thing_path(content, history_id: entry['id'], watch_list_id: watch_list_id)) : nil,
            class: 'history-link'
          )
        )
      end

      tag.li(safe_join(data.compact), class: is_active ? 'active' : '')
    end

    def complete_history_list(content)
      history_entries = []
      history_entries = ordered_history_entries(content) if content.updated_at.present? && content.updated_at.to_i != content.created_at.to_i

      locales_without_history = content.translated_locales.difference(content.histories.translated_locales)
      if locales_without_history.any?
        history_entries.push(
          {
            'id' => content.id,
            'created_by' => content.created_by,
            'updated_by' => content.updated_by,
            'created_at' => content.created_at,
            'updated_at' => content.updated_at,
            'class_name' => content.class.name,
            'version_name' => content.version_name,
            'created_by_user' => content.created_by_user,
            'updated_by_user' => content.updated_by_user,
            'locale' => locales_without_history.join(', ')
          }
        )
      end

      history_entries
    end

    def ordered_history_entries(content)
      query = <<-SQL.squish
          WITH content_history_list AS (
            SELECT
              t1.id AS id,
              t1.created_by AS created_by,
              t1.updated_by AS updated_by,
              t2.created_at AS created_at,
              LOWER(t2.history_valid) AS updated_at,
              t2.locale AS locale,
              'DataCycleCore::Thing::History' AS class_name,
              t1.version_name AS version_name
            FROM
              thing_histories t1
              INNER JOIN thing_history_translations t2 ON t2.thing_history_id = t1.id
            WHERE
              t1.thing_id = '#{content.id}'
            UNION ALL
            SELECT
              t3.id AS id,
              t3.created_by AS created_by,
              t3.updated_by AS updated_by,
              t3.created_at AS created_at,
              t4.updated_at AS updated_at,
              t4.locale AS locale,
              'DataCycleCore::Thing' AS class_name,
              t3.version_name AS version_name
            FROM
              things t3
              INNER JOIN thing_translations t4 ON t4.thing_id = t3.id
            WHERE
              t3.id = '#{content.id}'
          )
          SELECT
            *
          FROM
            content_history_list
          ORDER BY
            updated_at DESC,
            created_at DESC
      SQL

      history_entries = ActiveRecord::Base.connection.execute(query)
      users = DataCycleCore::User.where(id: history_entries.map { |t| t.values_at('created_by', 'updated_by') }.flatten.compact.uniq).group_by(&:id)

      history_entries.to_a.map do |entry|
        entry['created_by_user'] = users[entry['created_by']]&.first if entry['created_by'].present?
        entry['updated_by_user'] = users[entry['updated_by']]&.first if entry['updated_by'].present?
        entry
      end
    end
  end
end
