# frozen_string_literal: true

class MigrateTemplatesToOwnTable < ActiveRecord::Migration[6.1]
  # rubocop:disable Rails/BulkChangeTable
  def up
    execute <<-SQL.squish
      CREATE TABLE IF NOT EXISTS thing_templates (
        template_name varchar PRIMARY KEY NOT NULL,
        schema jsonb,
        computed_schema_types varchar[],
        content_type varchar GENERATED ALWAYS AS ("schema" ->> 'content_type') STORED,
        boost numeric GENERATED ALWAYS AS (("schema" -> 'boost')::numeric) STORED,
        created_at timestamp without time zone NOT NULL DEFAULT transaction_timestamp(),
        updated_at timestamp without time zone NOT NULL DEFAULT transaction_timestamp()
      );
    SQL

    add_index :thing_templates, :computed_schema_types, using: :gin
    add_index :thing_templates, :content_type, using: :btree
    add_index :thing_templates, :boost, using: :btree

    execute <<-SQL.squish
      DELETE FROM things
      WHERE template_name IS NULL;

      DELETE FROM thing_histories
      WHERE template_name IS NULL;
    SQL

    change_column_null(:things, :template_name, false)

    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS insert_thing_schema_types ON things;
      DROP TRIGGER IF EXISTS update_thing_schema_types ON things;

      CREATE TRIGGER insert_thing_templates_schema_types BEFORE
      INSERT ON thing_templates FOR EACH ROW EXECUTE FUNCTION generate_thing_schema_types ();

      CREATE TRIGGER update_thing_templates_schema_types BEFORE
      UPDATE of template_name,
        "schema" ON thing_templates FOR EACH ROW
        WHEN (
          OLD.template_name IS DISTINCT
          FROM NEW.template_name
            OR OLD."schema" IS DISTINCT
          FROM NEW."schema"
        ) EXECUTE FUNCTION generate_thing_schema_types ();

        DROP TRIGGER IF EXISTS update_template_definitions_trigger ON things;

        CREATE OR REPLACE FUNCTION update_template_definitions_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN
        UPDATE things
        SET boost = updated_thing_templates.boost,
          content_type = updated_thing_templates.content_type,
          cache_valid_since = NOW()
        FROM (
            SELECT DISTINCT ON (new_thing_templates.template_name) new_thing_templates.template_name,
              ("new_thing_templates"."schema"->'boost')::numeric AS boost,
              "new_thing_templates"."schema"->>'content_type' AS content_type
            FROM new_thing_templates
              INNER JOIN old_thing_templates ON old_thing_templates.template_name = new_thing_templates.template_name
            WHERE "new_thing_templates"."schema" IS DISTINCT
            FROM "old_thing_templates"."schema"
          ) "updated_thing_templates"
        WHERE things.template_name = updated_thing_templates.template_name;

        RETURN NULL;

        END;

        $$;

        CREATE TRIGGER update_template_definitions_trigger
        AFTER
        UPDATE ON thing_templates REFERENCING NEW TABLE AS new_thing_templates OLD TABLE AS old_thing_templates FOR EACH statement EXECUTE FUNCTION update_template_definitions_trigger ();

        CREATE OR REPLACE VIEW "content_properties" AS
        SELECT things.id AS content_id,
          things.template_name AS content_template_name,
          properties.key AS property_name,
          properties.value AS property_definition
        FROM things
          INNER JOIN thing_templates ON thing_templates.template_name = things.template_name
          CROSS JOIN lateral jsonb_each(
            ("thing_templates"."schema"->'properties'::text)
          ) AS properties(KEY, value);

        CREATE OR REPLACE VIEW content_meta_items AS
        SELECT things.id,
          'DataCycleCore::Thing' AS content_type,
          things.template_name,
          "thing_templates"."schema",
          things.external_source_id,
          things.external_key,
          things.created_by,
          things.updated_by,
          things.deleted_by
        FROM things
          INNER JOIN thing_templates ON thing_templates.template_name = things.template_name;
    SQL

    remove_index :things, name: :index_things_on_content_type, if_exists: true
    remove_index :things, name: :by_template_name_template, if_exists: true
    add_index :things, :template_name, if_not_exists: true
    remove_index :things, name: :index_things_on_schema_type, if_exists: true
    remove_index :things, name: :index_things_on_template_content_type_validity_range, if_exists: true
    add_index :things, [:id, :content_type, :validity_range, :template_name], name: 'things_id_content_type_validity_range_template_name_idx', if_not_exists: true
    remove_index :things, name: :index_things_template_template_name_idx, if_exists: true
    remove_index :things, name: :things_computed_schema_types_idx, if_exists: true
    remove_index :things, name: :things_template_name_template_uq_idx, if_exists: true

    execute <<-SQL.squish
      INSERT INTO thing_templates(template_name, "schema")
      SELECT DISTINCT ON (things.template_name) things.template_name,
        "things"."schema"
      FROM things
      WHERE "things"."template" = TRUE;

      DELETE FROM things
      WHERE things.template = TRUE;
    SQL

    remove_column :things, :computed_schema_types, if_exists: true
    remove_column :things, :schema, if_exists: true
    remove_column :things, :template, if_exists: true

    remove_column :thing_histories, :schema, if_exists: true
    remove_column :thing_histories, :template, if_exists: true

    add_foreign_key :things, :thing_templates, column: :template_name, primary_key: :template_name, on_delete: :nullify, validate: false
    add_foreign_key :thing_histories, :thing_templates, column: :template_name, primary_key: :template_name, on_delete: :nullify, validate: false
  end

  def down
    remove_foreign_key :things, :thing_templates
    remove_foreign_key :thing_histories, :thing_templates

    add_column :things, :schema, :jsonb, if_not_exists: true
    add_column :things, :template, :boolean, default: false, null: false, if_not_exists: true

    add_column :thing_histories, :schema, :jsonb, if_not_exists: true
    add_column :thing_histories, :template, :boolean, default: false, null: false, if_not_exists: true

    execute <<-SQL.squish
      ALTER TABLE things ADD COLUMN IF NOT EXISTS computed_schema_types VARCHAR[];

      DROP TRIGGER IF EXISTS insert_thing_schema_types ON things;
      DROP TRIGGER IF EXISTS update_thing_schema_types ON things;

      CREATE TRIGGER insert_thing_schema_types BEFORE
      INSERT ON things FOR EACH ROW EXECUTE FUNCTION generate_thing_schema_types ();

      CREATE TRIGGER update_thing_schema_types BEFORE
      UPDATE of template_name,
        "schema" ON things FOR EACH ROW
        WHEN (
          OLD.template_name IS DISTINCT
          FROM NEW.template_name
            OR OLD."schema" IS DISTINCT
          FROM NEW."schema"
        ) EXECUTE FUNCTION generate_thing_schema_types ();

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

      DROP TRIGGER IF EXISTS update_template_definitions_trigger ON things;

      CREATE TRIGGER update_template_definitions_trigger
        AFTER UPDATE OF schema,
        boost,
        content_type ON things
        FOR EACH ROW
        WHEN (NEW.template = TRUE AND (OLD.schema IS DISTINCT FROM NEW.schema OR OLD.boost IS DISTINCT FROM NEW.boost OR
          OLD.content_type IS DISTINCT FROM NEW.content_type))
        EXECUTE FUNCTION update_template_definitions_trigger ();

      INSERT INTO things(
          "schema",
          template_name,
          template,
          boost,
          content_type
        )
      SELECT "thing_templates"."schema",
        thing_templates.template_name,
        TRUE,
        ("thing_templates"."schema"->'boost')::numeric,
        "thing_templates"."schema"->>'content_type'
      FROM thing_templates;

      UPDATE thing_histories
      SET "schema" = "new_thing_templates"."schema",
        template = false
      FROM (
          SELECT "thing_templates"."schema",
            thing_templates.template_name
          FROM thing_templates
        ) "new_thing_templates"
      WHERE "new_thing_templates"."template_name" = thing_histories.template_name;

      CREATE INDEX IF NOT EXISTS index_things_on_content_type ON things (("schema" ->> 'content_type'));
      CREATE INDEX IF NOT EXISTS index_things_on_schema_type ON things (("schema" ->> 'schema_type'::TEXT));
      CREATE INDEX IF NOT EXISTS things_computed_schema_types_idx ON things USING gin (computed_schema_types);

      CREATE OR REPLACE VIEW "content_properties" AS
      SELECT things.id AS content_id,
        things.template_name AS content_template_name,
        properties.key AS property_name,
        properties.value AS property_definition
      FROM things,
        LATERAL jsonb_each((things.schema->'properties'::text)) properties(KEY, value);

      CREATE OR REPLACE VIEW content_meta_items AS
      SELECT id,
        'DataCycleCore::Thing' AS content_type,
        template_name,
        schema,
        external_source_id,
        external_key,
        created_by,
        updated_by,
        deleted_by
      FROM things
      WHERE template = FALSE;
    SQL

    add_index :things, [:template_name, :template], name: :by_template_name_template, if_not_exists: true
    add_index :things, [:id, :template, :content_type, :validity_range, :template_name], name: :index_things_on_template_content_type_validity_range, if_not_exists: true
    add_index :things, [:template, :template_name], name: :index_things_template_template_name_idx, if_not_exists: true
    add_index :things, [:template_name, :template], name: :things_template_name_template_uq_idx, if_not_exists: true

    drop_table :thing_templates, if_exists: true
  end
  # rubocop:enable Rails/BulkChangeTable
end
