# frozen_string_literal: true

class RandomizeSuperAdminPassword < ActiveRecord::Migration[6.1]
  def change
    password = SecureRandom.alphanumeric
    super_admin = DataCycleCore::User.with_deleted.where(email: 'admin@datacycle.at').or(DataCycleCore::User.with_deleted.where(email: 'admin@pixelpoint.at')).first
    if super_admin.present?
      super_admin.password = password
      super_admin.save
    end

    super_amdin_role = DataCycleCore::Role.find_by(rank: 99)
    pixel_super_admins = ['zlattinger@pixelpoint.at', 'oehzelt@pixelpoint.at', 'rainer@pixelpoint.at', 'mitterer@pixelpoint.at', 'preissig@pixelpoint.at']
    DataCycleCore::User.with_deleted.where(email: pixel_super_admins).update(role_id: super_amdin_role.id)
  end
end
