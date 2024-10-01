# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByUserGroupPermission < Base
        attr_reader :subject, :content_types

        def initialize(permission_key, *roles)
          @subject = DataCycleCore::User
          @permission_key = permission_key
          @roles = Array.wrap(roles).map(&:to_s)
        end

        def include?(user)
          role?(user) && user_group?(@permission_key)
        end

        private

        def to_restrictions(**)
          to_restriction(
            roles: Array.wrap(@roles).map { |v| I18n.t("roles.#{v}", locale:) }.join(', '),
            group: user_group?(@permission_key).pluck(:name).join(', ')
          )
        end

        def role?(user)
          return true if @roles.include?('all')
          user.is_role?(@roles)
        end

        def user_group?(permission_key)
          DataCycleCore::UserGroup.user_groups_with_permission(permission_key)
        end
      end
    end
  end
end
