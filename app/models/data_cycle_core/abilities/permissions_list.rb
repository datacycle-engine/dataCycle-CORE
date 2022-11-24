# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class PermissionsList
      include DataCycleCore::Abilities::Permissions::Roles::Common
      include DataCycleCore::Abilities::Permissions::Roles::Guest
      include DataCycleCore::Abilities::Permissions::Roles::ExternalUser
      include DataCycleCore::Abilities::Permissions::Roles::Standard
      include DataCycleCore::Abilities::Permissions::Roles::Admin
      include DataCycleCore::Abilities::Permissions::Roles::SuperAdmin

      def self.list
        unless defined? @list
          @list = []
          new.permissions
        end

        @list
      end

      def permissions
        ###############################################################################################################
        ################################### Core permissions
        ###############################################################################################################
        load_common_permissions
        load_guest_permissions
        load_external_user_permissions
        load_standard_permissions
        load_admin_permissions
        load_super_admin_permissions
      end

      def add_permission(condition, *actions, definition)
        raise 'missing condition in permission' if condition.blank?
        raise 'missing actions in permission' if actions.blank?
        raise 'missing definition in permission' if definition.blank?

        self.class.list.push({
          condition: condition,
          actions: actions,
          definition: definition
        })
      end

      def self.filtered_list(user)
        list.select { |l| l[:condition].include?(user) }
      end

      def self.add_abilities_for_user(ability)
        filtered_list(ability.user).each do |permission|
          definition = permission[:definition].clone
          definition.instance_variable_set(:@user, ability.user)
          definition.instance_variable_set(:@session, ability.session)

          parameters = [permission[:actions].first.to_sym, permission[:actions].from(1), definition.subject]
          parameters.push(definition.scope) if definition.respond_to?(:scope)
          parameters.push(definition.conditions) if definition.respond_to?(:conditions)
          next ability.send(*parameters) unless definition.respond_to?(:to_proc)

          ability.send(*parameters, &definition.to_proc)
        end
      end
    end
  end
end
