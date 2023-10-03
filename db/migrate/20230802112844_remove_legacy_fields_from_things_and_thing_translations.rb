# frozen_string_literal: true

class RemoveLegacyFieldsFromThingsAndThingTranslations < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE thing_translations DROP COLUMN IF EXISTS name,
        DROP COLUMN IF EXISTS description;
    SQL

    execute <<-SQL.squish
      ALTER TABLE thing_history_translations DROP COLUMN IF EXISTS name,
        DROP COLUMN IF EXISTS description;
    SQL

    execute <<-SQL.squish
      ALTER TABLE things DROP COLUMN IF EXISTS address_country,
        DROP COLUMN IF EXISTS address_locality,
        DROP COLUMN IF EXISTS elevation,
        DROP COLUMN IF EXISTS email,
        DROP COLUMN IF EXISTS end_date,
        DROP COLUMN IF EXISTS family_name,
        DROP COLUMN IF EXISTS fax_number,
        DROP COLUMN IF EXISTS given_name,
        DROP COLUMN IF EXISTS internal_name,
        DROP COLUMN IF EXISTS latitude,
        DROP COLUMN IF EXISTS longitude,
        DROP COLUMN IF EXISTS postal_code,
        DROP COLUMN IF EXISTS start_date,
        DROP COLUMN IF EXISTS street_address,
        DROP COLUMN IF EXISTS telephone;
    SQL

    execute <<-SQL.squish
      ALTER TABLE thing_histories DROP COLUMN IF EXISTS address_country,
        DROP COLUMN IF EXISTS address_locality,
        DROP COLUMN IF EXISTS elevation,
        DROP COLUMN IF EXISTS email,
        DROP COLUMN IF EXISTS end_date,
        DROP COLUMN IF EXISTS family_name,
        DROP COLUMN IF EXISTS fax_number,
        DROP COLUMN IF EXISTS given_name,
        DROP COLUMN IF EXISTS internal_name,
        DROP COLUMN IF EXISTS latitude,
        DROP COLUMN IF EXISTS longitude,
        DROP COLUMN IF EXISTS postal_code,
        DROP COLUMN IF EXISTS start_date,
        DROP COLUMN IF EXISTS street_address,
        DROP COLUMN IF EXISTS telephone;
    SQL

    execute <<-SQL.squish
      CREATE INDEX IF NOT EXISTS thing_translations_name_idx ON thing_translations((content->>'name'));
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE thing_translations
      ADD COLUMN name varchar,
        ADD COLUMN description text;

      ALTER TABLE thing_history_translations
      ADD COLUMN name varchar,
        ADD COLUMN description text;

      ALTER TABLE things
      ADD COLUMN address_country varchar,
        ADD COLUMN address_locality varchar,
        ADD COLUMN elevation double precision,
        ADD COLUMN email varchar,
        ADD COLUMN end_date timestamp without time zone,
        ADD COLUMN family_name varchar,
        ADD COLUMN fax_number varchar,
        ADD COLUMN given_name varchar,
        ADD COLUMN internal_name varchar,
        ADD COLUMN latitude double precision,
        ADD COLUMN longitude double precision,
        ADD COLUMN postal_code varchar,
        ADD COLUMN start_date timestamp without time zone,
        ADD COLUMN street_address varchar,
        ADD COLUMN telephone varchar;

      ALTER TABLE thing_histories
      ADD COLUMN address_country varchar,
        ADD COLUMN address_locality varchar,
        ADD COLUMN elevation double precision,
        ADD COLUMN email varchar,
        ADD COLUMN end_date timestamp without time zone,
        ADD COLUMN family_name varchar,
        ADD COLUMN fax_number varchar,
        ADD COLUMN given_name varchar,
        ADD COLUMN internal_name varchar,
        ADD COLUMN latitude double precision,
        ADD COLUMN longitude double precision,
        ADD COLUMN postal_code varchar,
        ADD COLUMN start_date timestamp without time zone,
        ADD COLUMN street_address varchar,
        ADD COLUMN telephone varchar;
    SQL
  end
end
