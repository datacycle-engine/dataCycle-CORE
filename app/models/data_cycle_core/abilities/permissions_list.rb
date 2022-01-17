# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class PermissionsList
      attr_accessor :list

      def initialize
        @list = []
      end

      def add_permission(condition, *actions, definition)
        list.push({
          condition: condition,
          actions: actions,
          definition: definition
        })
      end

      def filtered_list(user)
        list.select { |l| l[:condition].include?(user) }
      end

      def add_abilities_for_user(user, ability)
        filtered_list(user).each do |permission|
          parameters = [permission[:actions].first, permission[:actions].from(1), permission[:definition].subject]

          parameters.push(permission[:definition].conditions) if permission[:definition].respond_to?(:conditions)
          parameters.push(permission[:definition].to_proc) if permission[:definition].respond_to?(:to_proc)

          ability.send(*parameters)
        end
      end
    end
  end
end
