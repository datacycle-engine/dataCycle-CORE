# frozen_string_literal: true

class RenameColumnTemplateUpdatedAtToCacheValidSince < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
      ALTER TABLE things RENAME COLUMN template_updated_at TO cache_valid_since;

      ALTER TABLE thing_histories RENAME COLUMN template_updated_at TO cache_valid_since;

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
          cache_valid_since = NOW()
        WHERE
          things.template_name = NEW.template_name
          AND things.template = FALSE;
        RETURN new;
      END;
      $$;
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE things RENAME COLUMN cache_valid_since TO template_updated_at;

      ALTER TABLE thing_histories RENAME COLUMN cache_valid_since TO template_updated_at;

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
    SQL
  end
end
