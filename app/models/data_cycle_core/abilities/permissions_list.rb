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

      def segment(segment_name)
        return ::Abilities::Segments.const_get(segment_name) if Module.const_defined?("::Abilities::Segments::#{segment_name}")

        DataCycleCore::Abilities::Segments.const_get(segment_name)
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

      def permit(condition, *actions, definition)
        raise 'missing condition in permission' if condition.blank?
        raise 'missing actions in permission' if actions.blank?
        raise 'missing definition in permission' if definition.blank?

        self.class.list.push({
          condition:,
          actions:,
          definition:
        })
      end

      alias add_permission permit

      def permit_user(role, *, definition)
        raise 'missing role in permission' if role.blank?

        permit(segment(:UsersByRole).new(role), *, definition_to_segment(definition))
      end

      def permit_user_except(roles, *, definition)
        raise 'missing role in permission' if roles.blank?

        permit(segment(:UsersExceptRoles).new(roles), *, definition_to_segment(definition))
      end

      def permit_by_email_domain(domain, *, definition)
        raise 'missing domain in permission' if domain.blank?

        permit(segment(:UsersByEmailDomain).new(domain), *, definition_to_segment(definition))
      end

      def permit_user_group(group_name, roles, *, definition)
        raise 'missing user_group name in permission' if group_name.blank?
        raise 'missing roles in permission' if roles.blank?

        permit(segment(:UsersByUserGroup).new(group_name, roles), *, definition_to_segment(definition))
      end

      def definition_to_segment(definition)
        return segment(definition).new unless definition.is_a?(::Hash)

        definition_values = definition.values.first
        if definition_values.last.is_a?(::Hash)
          if definition_values.length > 1
            segment(definition.keys.first).new(*definition_values[0..-2], **definition_values[-1])
          else
            segment(definition.keys.first).new(**definition_values[0])
          end
        else
          segment(definition.keys.first).new(*definition_values)
        end
      end

      def self.filtered_list(user)
        list.select { |l| l[:condition].include?(user) }
      end

      def self.add_alias_actions(ability)
        ability.alias_action :manual_order, to: :update
      end

      def self.add_abilities_for_user(ability)
        add_alias_actions(ability)

        filtered_list(ability.user).each do |permission|
          definition = permission[:definition].clone
          definition.instance_variable_set(:@user, ability.user)
          definition.instance_variable_set(:@session, ability.session)

          parameters = [:can, permission[:actions], definition.subject]
          parameters.push(definition.scope) if definition.respond_to?(:scope)
          parameters.push(definition.conditions) if definition.respond_to?(:conditions)
          next ability.send(*parameters) unless definition.respond_to?(:to_proc)

          ability.send(*parameters, &definition.to_proc)
        end
      end
    end
  end
end
