# frozen_string_literal: true

class AddProvidersToUserTable < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :providers, :jsonb
    add_index :users, :providers, using: :gin

    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      UPDATE users
      SET providers = jsonb_build_object(provider, uid)
      WHERE provider IS NOT NULL
        AND uid IS NOT NULL;
    SQL
  end

  def down
  end
end
