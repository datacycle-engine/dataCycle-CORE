# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class RolesExcept < Base
        attr_reader :subject, :allowed, :conditions

        def initialize(except = [])
          except = Array.wrap(except).map(&:to_s)
          @allowed = DataCycleCore::Role.where.not(name: except).pluck(:name)
          @subject = DataCycleCore::Role
          @conditions = { name: @allowed }
        end
      end
    end
  end
end
