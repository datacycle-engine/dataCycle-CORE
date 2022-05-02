# frozen_string_literal: true

class UpdateTemplateDefinitionsViaTrigger < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION update_template_definitions_trigger ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        UPDATE
          things
        SET
          "schema" = NEW.schema,
          boost = (NEW.schema -> 'boost')::numeric,
          content_type = NEW.schema ->> 'content_type',
          template_updated_at = NOW()
        WHERE
          things.template_name = NEW.template_name
          AND things.template = FALSE;
        RETURN new;
      END;
      $$;

      CREATE TRIGGER update_template_definitions_trigger
        AFTER UPDATE OF schema,
        boost,
        content_type ON things
        FOR EACH ROW
        WHEN (NEW.template = TRUE AND (OLD.schema IS DISTINCT FROM NEW.schema OR OLD.boost IS DISTINCT FROM NEW.boost OR
          OLD.content_type IS DISTINCT FROM NEW.content_type))
        EXECUTE FUNCTION update_template_definitions_trigger ();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS update_template_definitions_trigger ON things;
      DROP FUNCTION IF EXISTS update_template_definitions_trigger;
    SQL
  end
end
