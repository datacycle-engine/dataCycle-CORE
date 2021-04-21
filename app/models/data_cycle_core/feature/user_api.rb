# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserApi < Base
      class << self
        def new_user_notification?
          configuration[:new_user_notification].present?
        end

        def users_to_notify
          emails = []

          emails.concat(DataCycleCore::UserGroup.find_by(name: configuration.dig(:new_user_notification, :user_group))&.users&.pluck(:email) || []) if configuration.dig(:new_user_notification, :user_group).present?

          emails.concat(Array.wrap(configuration.dig(:new_user_notification, :email)))

          emails.compact
        end

        def notify_users(new_user)
          DataCycleCore::UserApiMailer.notify(users_to_notify, new_user).deliver_later
        end

        def default_user_groups
          return if configuration.dig(:default_user_groups).blank?

          DataCycleCore::UserGroup.where(name: configuration[:default_user_groups])
        end
      end
    end
  end
end
