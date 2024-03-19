# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module Guest
          def load_guest_permissions(role = :guest)
            permit_user_from_yaml(role, :guest)
          end
        end
      end
    end
  end
end
