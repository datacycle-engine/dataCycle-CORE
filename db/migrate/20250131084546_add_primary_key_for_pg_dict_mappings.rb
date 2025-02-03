# frozen_string_literal: true

class AddPrimaryKeyForPgDictMappings < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE pg_dict_mappings
      ADD PRIMARY KEY (locale);
    SQL
  end

  def down
  end
end
