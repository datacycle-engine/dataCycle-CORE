# frozen_string_literal: true

module DataCycleCore
  module HistoryHelper
    INDICATOR_CLASSES = { '+' => 'has-changes new', '-' => 'has-changes remove', '~' => 'has-changes edit', '0' => 'has-changes irrelevant' }.freeze

    def attribute_changes(content, diff, key)
      return diff unless diff.present? && content.respond_to?(key)

      save_navigate(diff, [key])
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

    def new_content_collections(diff)
      added_ids = Array.wrap(changes_by_mode(diff, '+'))
      DataCycleCore::WatchList.where(id: added_ids).to_a + DataCycleCore::StoredFilter.where(id: added_ids).to_a
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

      tag.span(date_string, data: { dc_tooltip: title_string })
    end

    def history_by_link(user)
      link_text = t('terms.from', locale: active_ui_locale)

      if user.nil?
        safe_join([link_text, tag.b('System')], ' ')
      else
        safe_join(
          [
            link_text,
            tag.b(tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", data: { dc_tooltip: user.full_name }))
          ],
          ' '
        )
      end
    end

    def history_dropdown_link(user = nil)
      if user.nil?
        tag.span('System', class: 'email-link')
      else
        tag.a(user.full_name, class: 'email-link', href: "mailto:#{user.email}", data: { dc_tooltip: user.full_name })
      end
    end

    def version_name_html(item)
      version_name = []
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
              }
            )
          )
        end
      end
      tag.span(
        safe_join(version_name.compact),
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
          )
        )
      end

      data.push(version_name_html(item))
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
      created_locales = content
        .translations
        .where('thing_translations.created_at <= ?', content.created_at&.+(10.seconds))
        .pluck(:locale)

      content.translations.where.not(locale: content.histories.translated_locales + created_locales + [content.last_updated_locale]).find_each do |created_translation|
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

      history_entries
    end

    def ordered_history_entries(content)
      content
        .histories
        .includes(:translations, :updated_by_user)
        .map do |history|
          DataCycleCore::Content::HistoryListEntry.new(
            item: history,
            user: current_user,
            locales: history.translated_locales,
            icon: { class: 'fa fa-arrows-h', tooltip: 'history.active_version' }
          )
        end
    end

    def history_version_html(content)
      history_html = ActionView::OutputBuffer.new
      content.try(:updated_at)&.then { |date| history_html << t('history.updated_at_html', locale: active_ui_locale, language: content.first_available_locale(content.last_updated_locale), date: l(date.in_time_zone, locale: active_ui_locale, format: :history)) }
      history_html << ' '
      history_html << history_by_link(content.updated_by_user)

      history_html
    end

    def thing_from_histories(left, right)
      return left.thing, nil, false if left.nil? || right.nil?
      return left, right, false if left.history? && right.history?
      left.history? ? [right, left, true] : [left, right, true]
    end

    def publication_attribute_changes(date_changes, publication)
      case date_changes&.dig(0)
      when '~'
        tag.del(l(date_changes.dig(1).to_date, format: :long, locale: active_ui_locale)) + tag.ins(l(date_changes.dig(2).to_date, format: :long, locale: active_ui_locale))
      when '+'
        tag.ins(l(date_changes.dig(1).to_date, format: :long, locale: active_ui_locale))
      when '-'
        tag.del(l(publication&.publish_at&.to_date, format: :long, locale: active_ui_locale))
      else
        l(publication&.publish_at&.to_date, format: :long, locale: active_ui_locale)
      end
    end

    def diff_target_id(object)
      object.is_a?(DataCycleCore::Thing::History) ? object.try(:thing_id) : object.id
    end

    def diff_target_by_key(key:, diff_target: nil, **_args)
      return if diff_target.nil?

      diff_target.try(key&.attribute_name_from_key)
    end

    def diff_target_by_id(object:, **)
      diff_objects = diff_target_by_key(**)

      return if diff_objects.nil?

      case diff_objects
      when DataCycleCore::Thing::History.const_get(:ActiveRecord_AssociationRelation), DataCycleCore::Thing::History.const_get(:ActiveRecord_Relation)
        diff_objects.find_by(thing_id: diff_target_id(object))
      else
        diff_objects.find_by(id: diff_target_id(object))
      end
    end

    def object_viewer_history_options(object:, key:, options: {}, item_diff: nil, **_args)
      object_options = (options.deep_dup || {}).merge({ item_diff: attribute_changes(object, item_diff || options&.dig('item_diff'), key) }).with_indifferent_access
      object_options[:mode] = changes_mode(object_options[:item_diff])
      object_options[:force_render] = true if object.template_name == 'Publikations-Plan'

      object_options
    end
  end
end
