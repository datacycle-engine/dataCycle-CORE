# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module ContentLock
        extend ActiveSupport::Concern

        included do
          has_one :lock, -> { where(activity_type: 'content_lock').where('activities.updated_at >= ?', DataCycleCore::Feature::ContentLock.lock_length.seconds.ago) }, class_name: 'DataCycleCore::ContentLock', as: :activitiable, inverse_of: :activitiable
        end

        def locked_until
          lock&.locked_until
        end

        def locked?
          lock.present?
        end
      end
    end
  end
end
