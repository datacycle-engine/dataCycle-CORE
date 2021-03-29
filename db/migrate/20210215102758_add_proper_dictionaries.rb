# frozen_string_literal: true

class AddProperDictionaries < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DROP TRIGGER IF EXISTS tsvectorsearchupdate
      ON searches;

      CREATE OR REPLACE FUNCTION get_dict(lang varchar) RETURNS regconfig LANGUAGE PLPGSQL AS $$
      DECLARE
        dict regconfig;
      BEGIN
        SELECT
          CASE
            WHEN lang = 'da' THEN 'pg_catalog.danish'
            WHEN lang = 'nl' THEN 'pg_catalog.dutch'
            WHEN lang = 'en' THEN 'pg_catalog.english'
            WHEN lang = 'fi' THEN 'pg_catalog.finnish'
            WHEN lang = 'fr' THEN 'pg_catalog.french'
            WHEN lang = 'de' THEN 'pg_catalog.german'
            WHEN lang = 'de-CH' THEN 'pg_catalog.german'
            WHEN lang = 'hu' THEN 'pg_catalog.hungarian'
            WHEN lang = 'it' THEN 'pg_catalog.italian'
            WHEN lang = 'no' THEN 'pg_catalog.norwegian'
            WHEN lang = 'pt' THEN 'pg_catalog.portuguese'
            WHEN lang = 'ru' THEN 'pg_catalog.russian'
            WHEN lang = 'es' THEN 'pg_catalog.spanish'
            WHEN lang = 'sv' THEN 'pg_catalog.swedish'
            WHEN lang = 'tr' THEN 'pg_catalog.turkish'
            ELSE 'pg_catalog.simple'
          END
        INTO dict;
        RETURN dict;
      END; $$;

      CREATE OR REPLACE FUNCTION tsvectorsearchupdate() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      BEGIN
      	NEW.words := pg_catalog.to_tsvector(get_dict(NEW.locale), NEW.full_text::text);
        RETURN NEW;
      END;$$;
      CREATE TRIGGER tsvectorsearchupdate BEFORE INSERT OR UPDATE
      ON searches FOR EACH ROW EXECUTE FUNCTION
      tsvectorsearchupdate();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS tsvectorsearchupdate
      ON searches;
      CREATE TRIGGER tsvectorsearchupdate BEFORE INSERT OR UPDATE
      ON searches FOR EACH ROW EXECUTE PROCEDURE
      tsvector_update_trigger(words, 'pg_catalog.simple', full_text);
    SQL
  end
end
