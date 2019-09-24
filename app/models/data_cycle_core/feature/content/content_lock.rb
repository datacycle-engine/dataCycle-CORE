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

        class_methods do
          def locks
            DataCycleCore::ContentLock.where(activity_type: 'content_lock', activitiable: all).where('activities.updated_at >= ?', DataCycleCore::Feature::ContentLock.lock_length.seconds.ago).order(:updated_at)
          end

          def create_locks(user:)
            content_query = all.select("'DataCycleCore::Thing', things.id, '#{user.id}', 'content_lock', NOW(), NOW()")

            ActiveRecord::Base.connection.execute <<-SQL.squish
              INSERT INTO activities (activitiable_type, activitiable_id, user_id, activity_type, created_at, updated_at)
              #{content_query.to_sql}
              ON CONFLICT DO NOTHING
            SQL

            locks.reload.includes(:user, activitiable: [:translations, :watch_lists]).find_each { |cl| cl.send(:create_locks) }
          end
        end
      end
    end
  end
end
