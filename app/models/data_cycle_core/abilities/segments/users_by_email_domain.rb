# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByEmailDomain < Base
        attr_reader :subject

        def initialize(domain)
          @subject = DataCycleCore::User
          @domain = domain.to_s
        end

        def include?(user)
          user&.email&.end_with?(@domain)
        end

        private

        def to_restrictions(**)
          to_restriction(domain: @domain)
        end
      end
    end
  end
end
