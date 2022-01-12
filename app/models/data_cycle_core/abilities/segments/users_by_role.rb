# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByRole
        def initialize(role)
          @role = role
        end

        def include?(user)
          user.is_role?(@role)
        end
      end
    end
  end
end
