# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module SystemAdmin
          # A system admin has all the permissions of a super admin, plus some additional ones.
          def load_system_admin_permissions(role = :system_admin)
            permit_user_from_yaml(role, :common)
            permit_user_from_yaml(role, :super_admin)
            permit_user_from_yaml(role, :system_admin)
          end
        end
      end
    end
  end
end
