# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      # :nodoc:
      class UsersByEmail < Base
        attr_reader :subject

        def initialize(email)
          @subject = DataCycleCore::User
          @email = email.to_s
        end

        # :nodoc:
        def include?(user)
          user&.email&.casecmp?(@email)
        end

        private

        def to_restrictions(**)
          to_restriction(email: @email)
        end
      end
    end
  end
end
