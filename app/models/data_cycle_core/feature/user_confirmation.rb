# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserConfirmation < Base
      def enabled?
        super || UserRegistration.enabled?
      end
    end
  end
end
