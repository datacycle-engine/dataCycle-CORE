# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersExceptUserGroup < Base
        attr_accessor :group_name, :roles

        def initialize(group_name, roles)
          @group_name = group_name
          @roles = Array.wrap(roles).map(&:to_s)
        end

        def include?(user)
          role?(user) && not_user_group?(user)
        end

        private

        def to_restrictions(**)
          to_restriction(
            roles: Array.wrap(roles).map { |v| I18n.t("roles.#{v}", locale:) }.join(', '),
            group: group_name
          )
        end

        def role?(user)
          return true if roles.include?('all')

          user.is_role?(*roles)
        end

        def not_user_group?(user)
          !user.has_user_group?(group_name)
        end
      end
    end
  end
end
