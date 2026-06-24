# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module UserGroups
          def load_user_group_permissions(role = :all)
            permit_user_groups_from_yaml(role)
          end
        end
      end
    end
  end
end
