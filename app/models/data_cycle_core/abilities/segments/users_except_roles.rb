# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersExceptRoles < Base
        attr_reader :subject, :allowed, :conditions

        def initialize(except = [])
          except = Array.wrap(except).map(&:to_s)
          @subject = DataCycleCore::User
          @allowed = DataCycleCore::Role.where.not(name: except).pluck(:name)
          @conditions = { role: { name: @allowed } }
        end
      end
    end
  end
end
