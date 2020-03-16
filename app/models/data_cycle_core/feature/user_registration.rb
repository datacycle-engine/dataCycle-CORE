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
      end
    end
  end
end
