# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module UserGroups
          def load_permissions_for_user_groups(role = DataCycleCore::Feature::UserGroupPermission.configuration['default_role'] || :standard)
            DataCycleCore::Feature::UserGroupPermission.abilities.each do |k, v|
              actions = Array.wrap(v[:actions]).map(&:to_sym)
              permit_user_group_by_permission_key(k, role, *actions, {ThingsInCollections: [k]})
            end
          end
        end
      end
    end
  end
end
