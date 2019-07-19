# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module ContentLock
        extend ActiveSupport::Concern

        included do
          has_one :lock, -> { where(event_type: 'content_lock').where('events.updated_at >= ?', DataCycleCore::Feature::ContentLock.lock_length.seconds.ago) }, class_name: 'DataCycleCore::ContentLock', as: :eventable, inverse_of: :eventable
        end

        def locked_until
          lock&.updated_at&.utc&.+(DataCycleCore::Feature::ContentLock.lock_length.seconds)
        end
      end
    end
  end
end
