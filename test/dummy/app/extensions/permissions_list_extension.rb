# frozen_string_literal: true

module PermissionsListExtension
  def permissions
    ###############################################################################################################
    ################################### Core permissions
    ###############################################################################################################
    load_common_permissions
    load_guest_permissions
    load_external_user_permissions
    load_standard_permissions
    load_admin_permissions
    load_super_admin_permissions
  end
end

DataCycleCore::Abilities::PermissionsList.prepend(PermissionsListExtension)
