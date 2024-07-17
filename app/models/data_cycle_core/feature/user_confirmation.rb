# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserConfirmation < Base
      class << self
        def enabled?
          super || UserRegistration.enabled?
        end
      end
    end
  end
end
