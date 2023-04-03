# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByRole < Base
        attr_accessor :roles

        def initialize(*roles)
          @roles = Array.wrap(roles).flatten.map(&:to_s)
        end

        def include?(user)
          return true if roles.include?('all')

          user.is_role?(*roles)
        end
      end
    end
  end
end
