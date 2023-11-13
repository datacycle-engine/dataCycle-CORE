# frozen_string_literal: true

class UpgradePostgisExtensions < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      SELECT postgis_extensions_upgrade();
    SQL
  end

  def down
  end
end
