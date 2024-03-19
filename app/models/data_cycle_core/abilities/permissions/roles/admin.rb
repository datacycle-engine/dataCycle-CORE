# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module Admin
          def load_admin_permissions(role = :admin)
            permit_user_from_yaml(role, :admin)
          end
        end
      end
    end
  end
end
