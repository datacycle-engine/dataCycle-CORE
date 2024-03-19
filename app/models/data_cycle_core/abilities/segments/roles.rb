# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class Roles < Base
        attr_reader :subject, :conditions, :allowed_roles

        def initialize(*allowed)
          allowed = Array.wrap(allowed).flatten.map(&:to_s)
          allowed_roles = allowed.include?('all') ? DataCycleCore::Role.pluck(:name) : DataCycleCore::Role.where(name: allowed).pluck(:name)

          @subject = DataCycleCore::Role
          @conditions = { name: allowed_roles }
        end

        private

        def to_restrictions(**)
          to_restriction(roles: Array.wrap(allowed_roles).map { |v| I18n.t("roles.#{v}", locale:) }.join(', '))
        end
      end
    end
  end
end
