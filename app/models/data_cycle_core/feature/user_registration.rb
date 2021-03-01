# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserRegistration < Base
      class << self
        def privacy_policy_url
          configuration.dig('privacy_policy_url')
        end

        def terms_conditions_url
          configuration.dig('terms_condition_url')
        end

        def default_role
          role_name = 'standard'
          role_name = configuration.dig('default_role') if configuration.dig('default_role').present?

          DataCycleCore::Role.find_by(name: role_name)
        end
      end
    end
  end
end
