# frozen_string_literal: true

module DataCycleCore
  class ContentLock < DataCycleCore::Event
    after_commit :update_clients, on: [:create, :update]

    def locked_for
      (updated_at + DataCycleCore::Feature::ContentLock.lock_length.seconds - Time.zone.now).round
    end

    private

    def update_clients
      ActionCable.server.broadcast "content_lock_#{eventable.id}", locked_until: updated_at&.utc&.+(DataCycleCore::Feature::ContentLock.lock_length.seconds)&.to_i
    end
  end
end
