# frozen_string_literal: true

class ExportDictionaryMappingsToTable < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      CREATE TABLE IF NOT EXISTS pg_dict_mappings (
        locale varchar NOT NULL,
        dict varchar NOT NULL
      );

      CREATE UNIQUE INDEX pg_dict_mappings_locale_dict_idx ON pg_dict_mappings (locale, dict);

      INSERT INTO pg_dict_mappings (
        locale,
        dict)
      VALUES (
        'de',
        'pg_catalog.german'),
      (
        'en',
        'pg_catalog.english'),
      (
        'nl',
        'pg_catalog.dutch'),
      (
        'da',
        'pg_catalog.danish'),
      (
        'fi',
        'pg_catalog.finnish'),
      (
        'fr',
        'pg_catalog.french'),
      (
        'de-CH',
        'pg_catalog.german'),
      (
        'hu',
        'pg_catalog.hungarian'),
      (
        'it',
        'pg_catalog.italian'),
      (
        'no',
        'pg_catalog.norwegian'),
      (
        'pt',
        'pg_catalog.portuguese'),
      (
        'ru',
        'pg_catalog.russian'),
      (
        'es',
        'pg_catalog.spanish'),
      (
        'sv',
        'pg_catalog.swedish'),
      (
        'tr',
        'pg_catalog.turkish');

      DROP FUNCTION get_dict;

      CREATE OR REPLACE FUNCTION get_dict (
        lang varchar
      )
        RETURNS regconfig
        AS $$
        SELECT
          pg_dict_mappings.dict::regconfig
        FROM
          pg_dict_mappings
        WHERE
          pg_dict_mappings.locale IN (lang, 'simple')
        LIMIT 1;

      $$
      LANGUAGE SQL;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS get_dict;

      CREATE OR REPLACE FUNCTION get_dict (
        lang varchar
      )
        RETURNS regconfig
        LANGUAGE PLPGSQL
        AS $$
      DECLARE
        dict regconfig;
      BEGIN
        SELECT
          CASE WHEN lang = 'da' THEN
            'pg_catalog.danish'
          WHEN lang = 'nl' THEN
            'pg_catalog.dutch'
          WHEN lang = 'en' THEN
            'pg_catalog.english'
          WHEN lang = 'fi' THEN
            'pg_catalog.finnish'
          WHEN lang = 'fr' THEN
            'pg_catalog.french'
          WHEN lang = 'de' THEN
            'pg_catalog.german'
          WHEN lang = 'de-CH' THEN
            'pg_catalog.german'
          WHEN lang = 'hu' THEN
            'pg_catalog.hungarian'
          WHEN lang = 'it' THEN
            'pg_catalog.italian'
          WHEN lang = 'no' THEN
            'pg_catalog.norwegian'
          WHEN lang = 'pt' THEN
            'pg_catalog.portuguese'
          WHEN lang = 'ru' THEN
            'pg_catalog.russian'
          WHEN lang = 'es' THEN
            'pg_catalog.spanish'
          WHEN lang = 'sv' THEN
            'pg_catalog.swedish'
          WHEN lang = 'tr' THEN
            'pg_catalog.turkish'
          ELSE
            'pg_catalog.simple'
          END INTO dict;
        RETURN dict;
      END;
      $$;

      DROP INDEX IF EXISTS pg_dict_mappings_locale_dict_idx;

      DROP TABLE pg_dict_mappings;
    SQL
  end
end
