# frozen_string_literal: true

class RefactorPgDictMappings < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION get_dict (lang varchar) RETURNS regconfig LANGUAGE PLPGSQL AS $$
      DECLARE dict varchar;

      BEGIN
      SELECT pg_dict_mappings.dict::regconfig INTO dict
      FROM pg_dict_mappings
      WHERE pg_dict_mappings.locale IN (lang, 'simple')
      LIMIT 1;

      IF dict IS NULL THEN dict := 'pg_catalog.simple'::regconfig;

      END IF;

      RETURN dict;

      END;

      $$;

      DELETE FROM pg_dict_mappings
      WHERE pg_dict_mappings.dict = 'pg_catalog.simple'
    SQL
  end

  def down
  end
end
