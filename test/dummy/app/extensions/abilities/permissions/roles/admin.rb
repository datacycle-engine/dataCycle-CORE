# frozen_string_literal: true

module Abilities
  module Permissions
    module Roles
      module Admin
        def load_admin_permissions(role = :admin)
          super

          add_permission(
            DataCycleCore::Abilities::Segments::UsersByRole.new(role),
            :can, :show_history,
            DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::StoredFilter, :user_id)
          )

          add_permission(
            DataCycleCore::Abilities::Segments::UsersByRole.new(role),
            :can, :show, :bulk_edit, :bulk_delete,
            DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::WatchList)
          )
        end
      end
    end
  end
end

# @todo
# with ruby 2.7.1 we need to prepend PermissionList class because prepend on included modules don't work as aspected
# this will be fixed in ruby > 3.0
# DataCycleCore::Abilities::Permissions::Roles::ExternalUser.prepend(Abilities::Permissions::Roles::ExternalUser)
DataCycleCore::Abilities::PermissionsList.prepend(Abilities::Permissions::Roles::Admin)
