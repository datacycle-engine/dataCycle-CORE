# frozen_string_literal: true

class AddFunctionForWebsearchToTsqueryPrefix < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION websearch_to_prefix_tsquery(regconfig, text) RETURNS tsquery LANGUAGE plpgsql COST 101 IMMUTABLE STRICT PARALLEL SAFE AS $$ DECLARE  BEGIN RETURN REPLACE(
          websearch_to_tsquery($1, $2)::text || ' ',
          ''' ',
          ''':*'
        );

      END;

      $$;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS websearch_to_prefix_tsquery(regconfig, text);
    SQL
  end
end
