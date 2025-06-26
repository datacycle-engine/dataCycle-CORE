# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByRoleAndProvider < UsersByRole
        def initialize(*roles, provider)
          super(*roles)
          @provider = provider
        end

        def include?(user)
          super && user.send(:"#{@provider}_uid").present?
        end

        private

        def to_restrictions(**)
          role_string = roles.include?('all') ? I18n.t('roles.all', locale:) : Array.wrap(roles).map { |v| I18n.t("roles.#{v}", locale:) }.join(', ')

          to_restriction(roles: role_string, provider: @provider)
        end
      end
    end
  end
end
