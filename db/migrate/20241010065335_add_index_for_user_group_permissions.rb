# frozen_string_literal: true

class AddIndexForUserGroupPermissions < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE INDEX IF NOT EXISTS user_groups_permissions_idx ON public.user_groups USING gin (permissions);
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP INDEX IF EXISTS public.user_groups_permissions_idx;
    SQL
  end
end
