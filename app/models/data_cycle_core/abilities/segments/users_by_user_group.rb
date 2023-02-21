# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByUserGroup < Base
        attr_accessor :group_name, :roles

        def initialize(group_name, roles)
          @group_name = group_name
          @roles = Array.wrap(roles).map(&:to_s)
        end

        def include?(user)
          role?(user) && user_group?(user)
        end

        private

        def role?(user)
          return true if roles.include?('all')

          user.is_role?(*roles)
        end

        def user_group?(user)
          user.has_user_group?(group_name)
        end
      end
    end
  end
end
