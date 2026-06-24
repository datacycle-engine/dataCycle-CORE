# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class RolesExcept < Base
        attr_reader :subject, :conditions, :allowed

        def initialize(*except)
          except = Array.wrap(except).flatten.map(&:to_s)
          except += ['system_admin'] if except.exclude?('system_admin') # system_admin should always be excluded from the allowed roles
          @allowed = DataCycleCore::Role.where.not(name: except).pluck(:name)
          @subject = DataCycleCore::Role
          @conditions = { name: allowed }
        end

        private

        def to_restrictions(**)
          to_restriction(roles: Array.wrap(allowed).map { |v| I18n.t("roles.#{v}", locale:) }.join(', '))
        end
      end
    end
  end
end
