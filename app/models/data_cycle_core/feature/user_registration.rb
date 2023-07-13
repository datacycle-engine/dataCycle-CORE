# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserRegistration < Base
      class << self
        def privacy_policy_url
          configuration['privacy_policy_url']
        end

        def terms_conditions_url
          configuration['terms_condition_url']
        end

        def default_role
          DataCycleCore::Role.find_by(name: configuration['default_role'] || 'standard')
        end

        def terms_conditions_changed?(timestamp)
          return false unless configuration.key?('terms_condition_updated_at')
          return true if timestamp.blank?

          configuration['terms_condition_updated_at'].in_time_zone > timestamp.in_time_zone
        end

        def privacy_policy_changed?(timestamp)
          return false unless configuration.key?('privacy_policy_updated_at')
          return true if timestamp.blank?

          configuration['privacy_policy_updated_at'].in_time_zone > timestamp.in_time_zone
        end

        def users_outside_grace_period
          return DataCycleCore::User.none unless configuration.key?('consent_grace_period')

          query_base = DataCycleCore::User.where(locked_at: nil)
          query = []

          if configuration.key?('terms_condition_updated_at') && Time.zone.now >= (configuration['terms_condition_updated_at'].in_time_zone + configuration['consent_grace_period'])
            query.push(query_base.where("(users.additional_attributes ->> 'terms_conditions_at')::TIMESTAMP WITH TIME ZONE < ?::TIMESTAMP WITH TIME ZONE", configuration['terms_condition_updated_at']))
            query.push(query_base.where("users.additional_attributes ->> 'terms_conditions_at' IS NULL AND users.created_at < ?::TIMESTAMP WITHOUT TIME ZONE", Time.zone.now - configuration['consent_grace_period']))
          end

          if configuration.key?('privacy_policy_updated_at') && Time.zone.now >= (configuration['privacy_policy_updated_at'].in_time_zone + configuration['consent_grace_period'])
            query.push(query_base.where("(users.additional_attributes ->> 'privacy_policy_at')::TIMESTAMP WITH TIME ZONE < ?::TIMESTAMP WITH TIME ZONE", configuration['privacy_policy_updated_at']))
            query.push(query_base.where("users.additional_attributes ->> 'privacy_policy_at' IS NULL AND users.created_at < ?::TIMESTAMP WITHOUT TIME ZONE", Time.zone.now - configuration['consent_grace_period']))
          end

          query.reduce { |u, q| u ? u.or(q) : q } || DataCycleCore::User.none
        end

        def new_user_notification?
          enabled? && configuration[:new_user_notification].present?
        end

        def users_to_notify
          emails = []

          emails.concat(DataCycleCore::UserGroup.find_by(name: configuration.dig(:new_user_notification, :user_group))&.users&.pluck(:email) || []) if configuration.dig(:new_user_notification, :user_group).present?

          emails.concat(Array.wrap(configuration.dig(:new_user_notification, :email)))

          emails.compact
        end

        def notify_users(new_user)
          # DataCycleCore::UserRegistrationMailer.notify(users_to_notify, new_user).deliver_later
          DataCycleCore::UserRegistrationMailer.notify(users_to_notify, new_user).deliver_now
        end
      end
    end
  end
end
