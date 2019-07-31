# frozen_string_literal: true

module DataCycleCore
  class ContentLock < DataCycleCore::Activity
    include DataCycleCore::Engine.routes.url_helpers
    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

    after_create_commit :create_locks
    after_update_commit :update_locks
    after_destroy_commit :remove_locks

    def locked_for
      (updated_at + DataCycleCore::Feature::ContentLock.lock_length.seconds - Time.zone.now).round
    end

    def locked_until
      updated_at&.utc&.+(DataCycleCore::Feature::ContentLock.lock_length.seconds)
    end

    private

    def create_locks
      ActionCable.server.broadcast "content_lock_#{activitiable.id}",
                                   locked_until: locked_until&.to_i,
                                   create: true,
                                   button_text: tag.span(tag.br + tag.br + tag.i(t('common.content_locked_with_name_html', user: user&.full_name, data: distance_of_time_in_words(locked_for), name: I18n.with_locale(activitiable&.first_available_locale) { activitiable.try(:title) }, locale: DataCycleCore.ui_language)), id: "content-lock-#{id}", class: 'content-locked-text'),
                                   user_id: user.id,
                                   lock_id: id

      activitiable.watch_lists.ids.each do |watch_list_id|
        ActionCable.server.broadcast "content_lock_#{watch_list_id}",
                                     locked_until: locked_until&.to_i,
                                     create: true,
                                     button_text: tag.span(tag.br + tag.br + tag.i(t('common.content_locked_with_name_html', user: user&.full_name, data: distance_of_time_in_words(locked_for), name: I18n.with_locale(activitiable&.first_available_locale) { activitiable.try(:title) }, locale: DataCycleCore.ui_language)), id: "content-lock-#{id}", class: 'content-locked-text'),
                                     user_id: user.id,
                                     lock_id: id
      end
    end

    def update_locks
      ActionCable.server.broadcast "content_lock_#{activitiable.id}", locked_until: updated_at&.utc&.+(DataCycleCore::Feature::ContentLock.lock_length.seconds)&.to_i, user_id: user.id, lock_id: id

      activitiable.watch_lists.ids.each do |watch_list_id|
        ActionCable.server.broadcast "content_lock_#{watch_list_id}", locked_until: updated_at&.utc&.+(DataCycleCore::Feature::ContentLock.lock_length.seconds)&.to_i, user_id: user.id, lock_id: id
      end
    end

    def remove_locks
      ActionCable.server.broadcast "content_lock_#{activitiable.id}", remove_lock: true, user_id: user.id, lock_id: id

      activitiable.watch_lists.ids.each do |watch_list_id|
        ActionCable.server.broadcast "content_lock_#{watch_list_id}", remove_lock: true, user_id: user.id, lock_id: id
      end
    end
  end
end
