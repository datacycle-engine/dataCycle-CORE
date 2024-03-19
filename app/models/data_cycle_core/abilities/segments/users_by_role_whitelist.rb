# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByRoleWhitelist < Base
        attr_accessor :subject, :conditions, :roles

        def initialize(*whitelist)
          @subject = DataCycleCore::User
          @roles = Array.wrap(whitelist).flatten.map(&:to_s)
          @conditions = @roles.include?('all') ? {} : { role: { name: @roles } }
        end

        private

        def to_restrictions(**)
          return if roles.include?('all')

          to_restriction(roles: Array.wrap(roles).map { |v| I18n.t("roles.#{v}", locale:) }.join(', '))
        end
      end
    end
  end
end
