# frozen_string_literal: true

class AddDefaultValueForProviders < ActiveRecord::Migration[7.1]
  def up
    # Ensure existing records have an empty JSON object if providers is null
    execute <<-SQL.squish
      UPDATE users
      SET providers = '{}'::jsonb
      WHERE providers IS NULL;
    SQL

    change_table :users, bulk: true do |t|
      t.change_default :providers, {}
      t.change_null :providers, false
    end
  end

  def down
  end
end
