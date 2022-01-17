# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByRole
        attr_accessor :roles

        def initialize(roles)
          @roles = Array.wrap(roles)
        end

        def include?(user)
          user.is_role?(*roles)
        end
      end
    end
  end
end
