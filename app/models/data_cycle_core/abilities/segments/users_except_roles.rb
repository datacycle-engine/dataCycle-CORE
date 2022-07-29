# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersExceptRoles < Base
        attr_reader :except_roles, :subject, :allowed, :conditions

        def initialize(except = [])
          @except_roles = Array.wrap(except).map(&:to_s)
          @subject = DataCycleCore::User
          @allowed = DataCycleCore::Role.where.not(name: except_roles).pluck(:name)
          @conditions = { role: { name: @allowed } }
        end

        def include?(user)
          !user.is_role?(*except_roles)
        end
      end
    end
  end
end
