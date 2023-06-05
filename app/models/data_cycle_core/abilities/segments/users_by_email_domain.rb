# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByEmailDomain < Base
        def initialize(domain)
          @domain = domain.to_s
        end

        def include?(user)
          user&.email&.end_with?(@domain)
        end
      end
    end
  end
end
