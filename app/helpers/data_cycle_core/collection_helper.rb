# frozen_string_literal: true

module DataCycleCore
  module CollectionHelper
    CheckBoxStruct = Struct.new(:value, :text, :checked)

    def get_collection_groups(local_assigns)
      collection_group_index = local_assigns[:collection_group_index] || 0

      if local_assigns[:collection_group].present?
        group_title = local_assigns.dig(:collection_group, 0)
        collections = local_assigns.dig(:collection_group, 1)
        nested = true
      else
        collections = DataCycleCore::WatchList.accessible_by(current_ability).includes(:valid_write_links, :collection_shares, :user).without_my_selection
        collections = collections.fulltext_search(local_assigns[:q]) if local_assigns[:q].present?
        collections = collections.order(updated_at: :desc)
      end

      if DataCycleCore::Feature::CollectionGroup.enabled?
        collection_groups = collections.group_by { |c| c.full_path_names&.dig(collection_group_index) }
      else
        collection_groups = { nil => collections }
      end

      return collections, collection_groups, collection_group_index + 1, nested, group_title
    end

    def selected_collections?(collections, content_id)
      collections.any? { |c| c.watch_list_data_hashes.any? { |w| w.hashable_id == content_id && w.hashable_type == 'DataCycleCore::Thing' } }
    end

    def bulk_update_types(content, key, prop)
      label = translated_attribute_label(key, prop, content, {})
      check_boxes = [
        CheckBoxStruct.new('override', t('common.bulk_update.check_box_labels.override_html', locale: active_ui_locale, data: label))
      ]

      type = prop.dig('ui', 'bulk_edit', 'partial') || prop.dig('ui', 'edit', 'partial') || prop.dig('ui', 'edit', 'type') || prop['type']

      return check_boxes if type != 'classification' ||
                            prop.dig('ui', 'edit', 'options', 'multiple').to_s == 'false' ||
                            prop.dig('validations', 'max') == 1

      check_boxes.push(
        CheckBoxStruct.new('add', t('common.bulk_update.check_box_labels.add_html', locale: active_ui_locale, data: label)),
        CheckBoxStruct.new('remove', t('common.bulk_update.check_box_labels.remove_html', locale: active_ui_locale, data: label))
      )
    end

    def bulk_edit_button_title(content_locks, collection)
      return t('common.bulk_update.button.limited', data: DataCycleCore.global_configs[:bulk_update_limit], locale: active_ui_locale) if collection.things.size > DataCycleCore.global_configs[:bulk_update_limit]

      button_html = t('actions.bulk_edit', locale: active_ui_locale)

      return button_html if content_locks.blank?

      button_html += tag.span(tag.br + tag.br + t('common.multiple_content_locks_html', data: content_locks.size, locale: active_ui_locale), id: 'content-lock-multiple', class: "content-locked-text #{'hidden' if content_locks.size < 50}")

      button_html += safe_join(content_locks.map { |cl| tag.span(tag.br + tag.br + tag.i(t('common.content_locked_with_name_html', user: cl.user&.full_name, data: distance_of_time_in_words(cl.locked_for), name: I18n.with_locale(cl.activitiable&.first_available_locale) { cl.activitiable.try(:title) }, locale: active_ui_locale)), id: "content-lock-#{cl.id}", class: "content-locked-text #{'hidden' if content_locks.size >= 50}") })

      button_html
    end

    def render_my_selection(type:, content: nil)
      return if !DataCycleCore::Feature::MySelection.enabled? || current_user&.my_selection.nil?

      current_user.my_selection.clear_if_not_active

      render "data_cycle_core/application/watch_lists/#{type}_link",
             content:,
             watch_list: current_user.my_selection
    end

    def watch_list_link_icon(content)
      link_html = ActionView::OutputBuffer.new

      if content.watch_lists.loaded? ? content.watch_lists.any? { |w| can?(:read, w) } : content.watch_lists.accessible_by(current_ability).exists?
        link_html << tag.i(class: 'fa fa-bookmark')
        link_html << tag.i(class: 'fa fa-star my-collection-star-icon') if DataCycleCore::Feature::MySelection.enabled? && (content.watch_lists.loaded? ? content.watch_lists.any? { |w| w.my_selection && can?(:read, w) } : content.watch_lists.accessible_by(current_ability).my_selection.exists?)
      else
        link_html << tag.i(class: 'fa fa-bookmark-o')
      end

      link_html
    end

    def manual_order_allowed?(mode, language, filters)
      mode == 'list' && Array.wrap(language).include?('all') && filters.blank?
    end

    def watch_list_list_title(watch_list)
      safe_join([
        watch_list.collection_shares.any? ? tag.i(class: 'fa fa-users') : nil,
        watch_list.name,
        watch_list.api ? tag.span('API', class: 'content-title-api') : nil
      ].compact)
    end
  end
end
