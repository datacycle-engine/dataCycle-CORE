# frozen_string_literal: true

class AddUniqueIndexToUserGroupUsers < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      DELETE FROM user_group_users u1 WHERE u1.id NOT IN (SELECT DISTINCT ON (u2.user_group_id, u2.user_id) u2.id FROM user_group_users u2);
    SQL

    execute <<-SQL.squish
      CREATE UNIQUE INDEX IF NOT EXISTS user_group_users_on_user_id_user_group_id ON user_group_users USING btree (user_id, user_group_id);
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP INDEX IF EXISTS user_group_users_on_user_id_user_group_id ON user_group_users;
    SQL
  end
end
