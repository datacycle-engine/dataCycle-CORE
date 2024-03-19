# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByRole < Base
        attr_accessor :subject, :roles

        def initialize(*roles)
          @subject = DataCycleCore::User
          @roles = Array.wrap(roles).flatten.map(&:to_s)
        end

        def include?(user)
          return true if @roles.include?('all')

          user.is_role?(*@roles)
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
