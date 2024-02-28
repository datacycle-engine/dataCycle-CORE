# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module Standard
          def load_standard_permissions(role = :standard)
            permit_user_from_yaml(role, :standard)
          end
        end
      end
    end
  end
end
