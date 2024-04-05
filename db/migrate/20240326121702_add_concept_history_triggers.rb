# frozen_string_literal: true

class AddConceptHistoryTriggers < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION delete_concepts_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_histories
      SELECT * FROM old_concepts;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concepts_to_histories_trigger
      AFTER DELETE ON concepts REFERENCING OLD TABLE AS old_concepts FOR EACH STATEMENT EXECUTE FUNCTION delete_concepts_to_histories_trigger_function();

      CREATE OR REPLACE FUNCTION delete_concept_schemes_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_scheme_histories
      SELECT * FROM old_concept_schemes;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concept_schemes_to_histories_trigger
      AFTER DELETE ON concept_schemes REFERENCING OLD TABLE AS old_concept_schemes FOR EACH STATEMENT EXECUTE FUNCTION delete_concept_schemes_to_histories_trigger_function();

      CREATE OR REPLACE FUNCTION delete_concept_links_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_link_histories
      SELECT * FROM old_concept_links;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concept_links_to_histories_trigger
      AFTER DELETE ON concept_links REFERENCING OLD TABLE AS old_concept_links FOR EACH STATEMENT EXECUTE FUNCTION delete_concept_links_to_histories_trigger_function();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS delete_concepts_to_histories_trigger ON concepts;
      DROP TRIGGER IF EXISTS delete_concept_schemes_to_histories_trigger ON concept_schemes;
      DROP TRIGGER IF EXISTS delete_concept_links_to_histories_trigger ON concept_links;

      DROP FUNCTION IF EXISTS delete_concepts_to_histories_trigger_function;
      DROP FUNCTION IF EXISTS delete_concept_schemes_to_histories_trigger_function;
      DROP FUNCTION IF EXISTS delete_concept_links_to_histories_trigger_function;
    SQL
  end
end
