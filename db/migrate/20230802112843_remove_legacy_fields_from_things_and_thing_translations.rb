# frozen_string_literal: true

class RemoveLegacyFieldsFromThingsAndThingTranslations < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      UPDATE thing_translations
      SET content = coalesce(thing_translations.content, '{}') || jsonb_strip_nulls(
          jsonb_build_object(
            'name',
            thing_translations.name,
            'description',
            thing_translations.description
          )
        );

      UPDATE thing_history_translations
      SET content = coalesce(thing_history_translations.content, '{}') || jsonb_strip_nulls(
          jsonb_build_object(
            'name',
            thing_history_translations.name,
            'description',
            thing_history_translations.description
          )
        );

      UPDATE things
      SET metadata = coalesce(things.metadata, '{}') || jsonb_strip_nulls(
          jsonb_build_object(
            'address_country',
            things.address_country,
            'address_locality',
            things.address_locality,
            'elevation',
            things.elevation,
            'email',
            things.email,
            'end_date',
            things.end_date,
            'family_name',
            things.family_name,
            'fax_number',
            things.fax_number,
            'given_name',
            things.given_name,
            'internal_name',
            things.internal_name,
            'latitude',
            things.latitude,
            'longitude',
            things.longitude,
            'postal_code',
            things.postal_code,
            'start_date',
            things.start_date,
            'street_address',
            things.street_address,
            'telephone',
            things.telephone
          )
        );

      UPDATE thing_histories
      SET metadata = coalesce(thing_histories.metadata, '{}') || jsonb_strip_nulls(
          jsonb_build_object(
            'address_country',
            thing_histories.address_country,
            'address_locality',
            thing_histories.address_locality,
            'elevation',
            thing_histories.elevation,
            'email',
            thing_histories.email,
            'end_date',
            thing_histories.end_date,
            'family_name',
            thing_histories.family_name,
            'fax_number',
            thing_histories.fax_number,
            'given_name',
            thing_histories.given_name,
            'internal_name',
            thing_histories.internal_name,
            'latitude',
            thing_histories.latitude,
            'longitude',
            thing_histories.longitude,
            'postal_code',
            thing_histories.postal_code,
            'start_date',
            thing_histories.start_date,
            'street_address',
            thing_histories.street_address,
            'telephone',
            thing_histories.telephone
          )
        );

      ALTER TABLE thing_translations DROP COLUMN name,
        DROP COLUMN description;

      ALTER TABLE thing_history_translations DROP COLUMN name,
        DROP COLUMN description;

      ALTER TABLE things DROP COLUMN address_country,
        DROP COLUMN address_locality,
        DROP COLUMN elevation,
        DROP COLUMN email,
        DROP COLUMN end_date,
        DROP COLUMN family_name,
        DROP COLUMN fax_number,
        DROP COLUMN given_name,
        DROP COLUMN internal_name,
        DROP COLUMN latitude,
        DROP COLUMN longitude,
        DROP COLUMN postal_code,
        DROP COLUMN start_date,
        DROP COLUMN street_address,
        DROP COLUMN telephone;

      ALTER TABLE thing_histories DROP COLUMN address_country,
        DROP COLUMN address_locality,
        DROP COLUMN elevation,
        DROP COLUMN email,
        DROP COLUMN end_date,
        DROP COLUMN family_name,
        DROP COLUMN fax_number,
        DROP COLUMN given_name,
        DROP COLUMN internal_name,
        DROP COLUMN latitude,
        DROP COLUMN longitude,
        DROP COLUMN postal_code,
        DROP COLUMN start_date,
        DROP COLUMN street_address,
        DROP COLUMN telephone;

      CREATE INDEX IF NOT EXISTS thing_translations_name_idx ON thing_translations((content->>'name'));
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE thing_translations
      ADD COLUMN name varchar,
        ADD COLUMN description text;

      UPDATE thing_translations
      SET name = thing_translations.content->>'name',
        description = thing_translations.content->>'description';

      ALTER TABLE thing_history_translations
      ADD COLUMN name varchar,
        ADD COLUMN description text;

      UPDATE thing_history_translations
      SET name = thing_history_translations.content->>'name',
        description = thing_history_translations.content->>'description';

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

      UPDATE things
      SET address_country = things.metadata->>'address_country',
        address_locality = things.metadata->>'address_locality',
        elevation = (things.metadata->>'elevation')::double precision,
        email = things.metadata->>'email',
        end_date = (things.metadata->>'end_date')::timestamp without time zone,
        family_name = things.metadata->>'family_name',
        fax_number = things.metadata->>'fax_number',
        given_name = things.metadata->>'given_name',
        internal_name = things.metadata->>'internal_name',
        latitude = (things.metadata->>'latitude')::double precision,
        longitude = (things.metadata->>'longitude')::double precision,
        postal_code = things.metadata->>'postal_code',
        start_date = (things.metadata->>'start_date')::timestamp without time zone,
        street_address = things.metadata->>'street_address',
        telephone = things.metadata->>'telephone';

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

      UPDATE thing_histories
      SET address_country = thing_histories.metadata->>'address_country',
        address_locality = thing_histories.metadata->>'address_locality',
        elevation = (thing_histories.metadata->>'elevation')::double precision,
        email = thing_histories.metadata->>'email',
        end_date = (thing_histories.metadata->>'end_date')::timestamp without time zone,
        family_name = thing_histories.metadata->>'family_name',
        fax_number = thing_histories.metadata->>'fax_number',
        given_name = thing_histories.metadata->>'given_name',
        internal_name = thing_histories.metadata->>'internal_name',
        latitude = (thing_histories.metadata->>'latitude')::double precision,
        longitude = (thing_histories.metadata->>'longitude')::double precision,
        postal_code = thing_histories.metadata->>'postal_code',
        start_date = (thing_histories.metadata->>'start_date')::timestamp without time zone,
        street_address = thing_histories.metadata->>'street_address',
        telephone = thing_histories.metadata->>'telephone';
    SQL
  end
end
