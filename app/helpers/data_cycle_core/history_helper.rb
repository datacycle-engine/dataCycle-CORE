# frozen_string_literal: true

module DataCycleCore
  module HistoryHelper
<<<<<<< HEAD
    INDICATOR_CLASSES = { '+' => 'has-changes new', '-' => 'has-changes remove', '~' => 'has-changes edit' }.freeze
=======
    INDICATOR_CLASSES = { '+' => 'has-changes new', '-' => 'has-changes remove', '~' => 'has-changes edit', '0' => 'has-changes irrelevant' }.freeze
>>>>>>> old/develop

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

<<<<<<< HEAD
      tag.span(date_string, title: title_string)
=======
      tag.span(date_string, data: { dc_tooltip: title_string })
>>>>>>> old/develop
    end

    def history_by_link(user)
      link_text = t('terms.from', locale: active_ui_locale)

      if user.nil?
        safe_join([link_text, tag.b('System')], ' ')
      else
        safe_join(
          [
            link_text,
<<<<<<< HEAD
            tag.b(tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", title: user.full_name))
=======
            tag.b(tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", data: { dc_tooltip: user.full_name }))
>>>>>>> old/develop
          ],
          ' '
        )
      end
    end

    def history_dropdown_link(user = nil)
      if user.nil?
        tag.span('System', class: 'email-link')
      else
<<<<<<< HEAD
        tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", title: user.full_name)
=======
        tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", data: { dc_tooltip: user.full_name })
>>>>>>> old/develop
      end
    end

    def version_name_html(item)
      version_name = []
<<<<<<< HEAD
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
=======
      if item.version_name.present?
        version_name.push(
          tag.i(
            class: 'fa fa-tag version-name has-tip copy-to-clipboard',
            data: {
              value: item.version_name,
              dc_tooltip: t('feature.named_version.version_name', name: item.version_name, locale: active_ui_locale)
            }
          )
        )
        if item.can_remove_version_name
          version_name.push(
            link_to(
              tag.i(class: 'fa fa-times alert-color'),
              remove_version_name_path(class_name: item.class_name, id: item.id),
              remote: true,
              class: 'remove-version-name-link',
              method: :patch,
              data: {
                confirm: t('feature.named_version.confirm_remove', locale: active_ui_locale, name: item.version_name),
                dc_tooltip: t('feature.named_version.remove_version_name', locale: active_ui_locale)
>>>>>>> old/develop
              }
            )
          )
        end
      end
      tag.span(
        safe_join(version_name.compact),
<<<<<<< HEAD
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
=======
        class: "named-version-container#{' removable' if item.can_remove_version_name}",
        id: "version-name-#{item.id}"
      )
    end

    def history_link_icon(item)
      return if item.icon.blank?

      tag.i(class: item.icon[:class], data: { dc_tooltip: t(item.icon[:tooltip], locale: active_ui_locale) })
    end

    def history_link(content, item)
      tag.span(class: 'history-link') do
        if item.icon_only
          history_link_icon(item)
        elsif can?(:history, content)
          link_to_unless(item.active?, history_link_icon(item), history_thing_path(item.history_thing_path_params(content)))
        end
      end
    end

    def history_dropdown_line(content, item, watch_list_id, active_id = nil, diff_id = nil, right_side = false, diff_view = false)
      data = []
      item.watch_list_id = watch_list_id
      item.active_id = active_id
      item.diff_id = diff_id
      item.right_side = right_side
      item.diff_view = diff_view

      data.push(history_dropdown_link(item.updated_by_user))
      data.push(tag.span(item.locale.presence&.then { |s| "(#{s})" }, class: 'history-locale'))

      if item.updated_at.present?
        data.push(
          tag.span(
            l(item.updated_at.in_time_zone, locale: active_ui_locale, format: :history),
            class: 'history-time',
            data: { dc_tooltip: l(item.updated_at.in_time_zone, locale: active_ui_locale) }
>>>>>>> old/develop
          )
        )
      end

      data.push(version_name_html(item)) if DataCycleCore::Feature::NamedVersion.enabled?

<<<<<<< HEAD
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

=======
      data.push(history_link(content, item))

      tag.li(safe_join(data.compact), class: item.active_class)
    end

    def add_current_history_entries(content, history_entries)
      return unless content.histories.exists? || (content.updated_at.present? && content.updated_at.to_i != content.created_at.to_i)

      history_entries.push(
        DataCycleCore::Content::HistoryListEntry.new(
          item: content,
          user: current_user,
          locales: content.last_updated_locale,
          is_active: true,
          icon: { class: 'fa fa-arrows-h', tooltip: 'history.active_version' }
        )
      )

      history_entries.concat(ordered_history_entries(content))
    end

    def add_translations_history_entries(content, history_entries)
>>>>>>> old/develop
      created_locales = content
        .translations
        .where('thing_translations.created_at <= ?', content.created_at&.+(10.seconds))
        .pluck(:locale)

      content.translations.where.not(locale: content.histories.translated_locales + created_locales + [content.last_updated_locale]).each do |created_translation|
<<<<<<< HEAD
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
=======
        history_entries.push(
          DataCycleCore::Content::HistoryListEntry.new(
            user: current_user,
            id: SecureRandom.uuid,
            class_name: content.class.name,
            updated_at: [created_translation.created_at, created_translation.updated_at - 1.second, content.updated_at - 1.second].min,
            locale: created_translation.locale,
            can_remove_version_name: false,
            icon_only: true,
            icon: { class: 'fa fa-plus history-created-icon', tooltip: 'history.created' }
          )
        )
      end

      history_entries.push(
        DataCycleCore::Content::HistoryListEntry.new(
          item: content,
          user: current_user,
          locales: created_locales,
          attribute_type: :created,
          include_version_name: false,
          id: SecureRandom.uuid,
          icon_only: true,
          icon: { class: 'fa fa-plus history-created-icon', tooltip: 'history.created' }
        )
      )
    end

    def complete_history_list(content)
      history_entries = []

      return history_entries if content.nil?

      content = content.thing if content.history?

      add_current_history_entries(content, history_entries)
      add_translations_history_entries(content, history_entries)

      history_entries.sort! { |a, b| b.updated_at.to_i - a.updated_at.to_i }
>>>>>>> old/develop

      history_entries
    end

    def ordered_history_entries(content)
      content
        .histories
        .includes(:translations, :updated_by_user)
<<<<<<< HEAD
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
=======
        .map do |history|
          DataCycleCore::Content::HistoryListEntry.new(
            item: history,
            user: current_user,
            locales: history.translated_locales,
            icon: { class: 'fa fa-arrows-h', tooltip: 'history.active_version' }
          )
        end
>>>>>>> old/develop
    end

    def history_version_html(content)
      date = content.try(:history_valid)&.first || content.try(:updated_at)

      history_html = ActionView::OutputBuffer.new
<<<<<<< HEAD
      history_html << t('history.updated_at_html', locale: active_ui_locale, language: content.last_updated_locale || content.first_available_locale, date: l(date, locale: active_ui_locale, format: :history)) if date.present?
=======
      history_html << t('history.updated_at_html', locale: active_ui_locale, language: content.last_updated_locale || content.first_available_locale, date: l(date.in_time_zone, locale: active_ui_locale, format: :history)) if date.present?
>>>>>>> old/develop
      history_html << ' '
      history_html << history_by_link(content.updated_by_user)

      history_html
    end
<<<<<<< HEAD
=======

    def thing_from_histories(left, right)
      return left.thing, nil, false if left.nil? || right.nil?
      return left, right, false if left.history? && right.history?
      left.history? ? [right, left, true] : [left, right, true]
    end
>>>>>>> old/develop
  end
end
