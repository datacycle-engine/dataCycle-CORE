# frozen_string_literal: true

class MakeOauthUsersSystemAdmins < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    system_admin_role = DataCycleCore::Role.where(rank: 100).first_or_create({ name: 'system_admin' })

    # Find all users who have signed up/signed in with OAuth
    # OAuth users have a non-empty providers JSONB field
    oauth_users = DataCycleCore::User.where("providers ? 'pixelpoint_aad_v2'")

    oauth_users.update_all(role_id: system_admin_role.id)
  end

  def down
    super_admin_role = DataCycleCore::Role.find_by(rank: 99)
    return unless super_admin_role

    oauth_users = DataCycleCore::User.where("providers ? 'pixelpoint_aad_v2'")
    oauth_users.update_all(role_id: super_admin_role.id)
  end
end
