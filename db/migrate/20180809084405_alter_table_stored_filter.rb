# frozen_string_literal: true

class AlterTableStoredFilter < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      ALTER TABLE stored_filters ALTER COLUMN language TYPE character varying[] USING ARRAY[language];
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE stored_filters ALTER COLUMN language TYPE character varying USING language[1];
    SQL
  end
end
