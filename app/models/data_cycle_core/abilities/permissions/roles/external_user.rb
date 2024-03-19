# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module ExternalUser
          def load_external_user_permissions(role = :external_user)
            permit_user_from_yaml(role, :external_user)
          end
        end
      end
    end
  end
end
