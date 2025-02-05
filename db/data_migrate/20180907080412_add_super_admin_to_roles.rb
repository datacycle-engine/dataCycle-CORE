# frozen_string_literal: true

class AddSuperAdminToRoles < ActiveRecord::Migration[5.1]
  def up
    super_admin = DataCycleCore::Role.where(rank: 99).first_or_create do |user|
      user.name = 'super_admin'
    end

    super_admins = ['tester', 'admin', 'zlattinger', 'oehzelt', 'rainer', 'mitterer']
    super_admins = super_admins.map { |n| ["#{n}@datacycle.at", "#{n}@pixelpoint.at"] }.flatten

    DataCycleCore::User.with_deleted.where(email: super_admins).update(role_id: super_admin.id)
  end

  def down
    return unless DataCycleCore::Role.exists?(rank: 99)

    super_admins = DataCycleCore::User.with_deleted.where(role_id: DataCycleCore::Role.find_by(rank: 99).id)
    super_admins.update(role_id: DataCycleCore::Role.order('rank DESC').second.id)
    DataCycleCore::Role.find_by(rank: 99).destroy
  end
end
