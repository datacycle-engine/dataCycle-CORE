# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module SuperAdmin
          def load_super_admin_permissions(role = :super_admin)
            permit_user_from_yaml(role, :super_admin)
          end
        end
      end
    end
  end
end
