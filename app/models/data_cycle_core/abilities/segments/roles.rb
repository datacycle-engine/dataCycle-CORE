# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class Roles < Base
        attr_reader :subject, :conditions

        def initialize(*allowed)
          allowed = Array.wrap(allowed).flatten.map(&:to_s)
          allowed_roles = allowed.include?('all') ? DataCycleCore::Role.all.pluck(:name) : DataCycleCore::Role.where(name: allowed).pluck(:name)

          @subject = DataCycleCore::Role
          @conditions = { name: allowed_roles }
        end
      end
    end
  end
end
