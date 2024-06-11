# frozen_string_literal: true

class CleanUpPgDictMappings < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DELETE FROM pg_dict_mappings pdm
      WHERE pdm.dict::varchar ilike 'pg_catalog.%'
        AND EXISTS (
          SELECT 1
          FROM pg_dict_mappings pdm2
          WHERE pdm2.locale = pdm.locale
            AND pdm2.dict::varchar = REPLACE(pdm.dict::varchar, 'pg_catalog.', '')
        );

      UPDATE pg_dict_mappings
      SET dict = REPLACE(pg_dict_mappings.dict::varchar, 'pg_catalog.', '')::regconfig
      WHERE pg_dict_mappings.dict::varchar ilike 'pg_catalog.%';
    SQL
  end

  def down
  end
end
