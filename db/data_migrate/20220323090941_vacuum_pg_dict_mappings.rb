# frozen_string_literal: true

class VacuumPgDictMappings < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      VACUUM ANALYZE pg_dict_mappings;
    SQL
  end

  def down
  end
end
