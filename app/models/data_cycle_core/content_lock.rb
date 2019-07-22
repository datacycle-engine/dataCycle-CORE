# frozen_string_literal: true

module DataCycleCore
  class ContentLock < DataCycleCore::Event
    after_create_commit :create_locks
    after_update_commit :update_locks
    after_destroy_commit :remove_locks
    include ActionView::Helpers::DateHelper

    def locked_for
      (updated_at + DataCycleCore::Feature::ContentLock.lock_length.seconds - Time.zone.now).round
    end

    private

    def create_locks
      ActionCable.server.broadcast "content_lock_#{eventable.id}", locked_until: updated_at&.utc&.+(DataCycleCore::Feature::ContentLock.lock_length.seconds)&.to_i, create: true, button_text: I18n.t('common.content_locked', user: user&.full_name, data: distance_of_time_in_words(locked_for), locale: DataCycleCore.ui_language)
    end

    def update_locks
      ActionCable.server.broadcast "content_lock_#{eventable.id}", locked_until: updated_at&.utc&.+(DataCycleCore::Feature::ContentLock.lock_length.seconds)&.to_i
    end

    def remove_locks
      ActionCable.server.broadcast "content_lock_#{eventable.id}", remove_lock: true
    end
  end
end
