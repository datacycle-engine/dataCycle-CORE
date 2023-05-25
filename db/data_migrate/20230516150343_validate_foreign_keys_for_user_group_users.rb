# frozen_string_literal: true

class ValidateForeignKeysForUserGroupUsers < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      DELETE FROM user_group_users
      WHERE NOT EXISTS (
          SELECT 1
          FROM user_groups
          WHERE user_groups.id = user_group_users.user_group_id
        );

      DELETE FROM user_group_users
      WHERE NOT EXISTS (
          SELECT 1
          FROM users
          WHERE users.id = user_group_users.user_id
        );
    SQL

    validate_foreign_key :user_group_users, :users
    validate_foreign_key :user_group_users, :user_groups
  end

  def down
  end
end
