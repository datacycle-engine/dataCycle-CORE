# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersExceptRoles < Base
        attr_reader :subject, :conditions

        def initialize(*roles)
          @roles = Array.wrap(roles).flatten.map(&:to_s)
          @subject = DataCycleCore::User
          @allowed = DataCycleCore::Role.where.not(name: @roles).pluck(:name)
          @conditions = { role: { name: @allowed } }
        end

        def include?(user)
          user.is_role?(*@allowed)
        end
      end
    end
  end
end
