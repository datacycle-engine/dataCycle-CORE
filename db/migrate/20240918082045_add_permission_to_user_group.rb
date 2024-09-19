# frozen_string_literal: true

class AddPermissionToUserGroup < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
        alter table public.user_groups
        add permissions jsonb;
        END;
    SQL
  end
end
