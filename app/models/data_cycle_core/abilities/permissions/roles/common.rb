# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module Common
          def load_common_permissions(role = :all)
            permit_user_from_yaml(role, :common)
          end
        end
      end
    end
  end
end
