# frozen_string_literal: true

class AddColumnsToSearches < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE searches
      ADD COLUMN slug varchar;

      ALTER TABLE searches
      ADD COLUMN dict regconfig;

      INSERT INTO pg_dict_mappings (locale, dict) VALUES ('ar', 'simple'), ('bg', 'simple'), ('cs', 'simple'), ('hr', 'simple'), ('ja', 'simple'), ('ko', 'simple'), ('pl', 'simple'), ('ro', 'simple'), ('sl', 'simple'), ('sk', 'simple'), ('uk', 'simple'), ('nl-BE', 'dutch'), ('zh', 'simple');

      CREATE OR REPLACE FUNCTION get_dict (lang varchar) RETURNS regconfig LANGUAGE PLPGSQL IMMUTABLE STRICT PARALLEL SAFE AS $$
      DECLARE dict regconfig;

      BEGIN
      SELECT pg_dict_mappings.dict INTO dict
      FROM pg_dict_mappings
      WHERE pg_dict_mappings.locale = lang
      LIMIT 1;

      RETURN dict;

      END;

      $$;

      CREATE OR REPLACE FUNCTION update_dict_in_searches() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN NEW.dict = get_dict(NEW.locale);

      RETURN NEW;

      END;

      $$;

      ALTER TABLE pg_dict_mappings
      ALTER COLUMN dict
      TYPE regconfig USING dict::regconfig;

      CREATE TRIGGER dict_update_in_searches_trigger BEFORE
      UPDATE OF locale ON searches FOR EACH ROW
        WHEN (
          OLD.locale IS DISTINCT
          FROM NEW.locale
        ) EXECUTE FUNCTION update_dict_in_searches();

      CREATE TRIGGER dict_insert_in_searches_trigger BEFORE
      INSERT ON searches FOR EACH ROW EXECUTE FUNCTION update_dict_in_searches();

      ALTER TABLE searches
      ADD COLUMN search_vector tsvector generated always AS (
          setweight(
            to_tsvector(dict, coalesce(headline, '')),
            'A'
          ) || setweight(
            to_tsvector(dict, coalesce(slug, '')),
            'B'
          ) || setweight(
            to_tsvector(
              dict,
              coalesce(classification_string, '')
            ),
            'C'
          ) || setweight(
            to_tsvector(dict, coalesce(full_text, '')),
            'D'
          )
        ) stored;

      CREATE INDEX searches_search_vector_idx ON searches USING gin(search_vector);

      CREATE OR REPLACE FUNCTION tsvectorsearchupdate() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN NEW.words := to_tsvector(NEW.dict, NEW.full_text::text);

      RETURN NEW;

      END;

      $$;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS dict_insert_in_searches_trigger ON searches;
      DROP TRIGGER IF EXISTS dict_update_in_searches_trigger ON searches;
      DROP FUNCTION IF EXISTS update_dict_in_searches();

      CREATE OR REPLACE FUNCTION tsvectorsearchupdate() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN NEW.words := to_tsvector(get_dict(NEW.locale), NEW.full_text::text);

      RETURN NEW;

      END;

      $$;

      ALTER TABLE searches DROP COLUMN IF EXISTS search_vector;
      ALTER TABLE searches DROP COLUMN IF EXISTS slug;
      ALTER TABLE searches DROP COLUMN IF EXISTS dict;

      ALTER TABLE pg_dict_mappings
      ALTER COLUMN dict
      TYPE varchar USING dict::varchar;

      DROP FUNCTION IF EXISTS get_dict_locale (lang varchar);

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

      DELETE FROM pg_dict_mappings WHERE pg_dict_mappings.dict = 'simple'::regconfig;
    SQL
  end
end
