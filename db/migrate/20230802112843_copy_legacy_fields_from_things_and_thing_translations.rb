# frozen_string_literal: true

class CopyLegacyFieldsFromThingsAndThingTranslations < ActiveRecord::Migration[6.1]
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
    SQL

    execute <<-SQL.squish
      UPDATE thing_history_translations
      SET content = coalesce(thing_history_translations.content, '{}') || jsonb_strip_nulls(
          jsonb_build_object(
            'name',
            thing_history_translations.name,
            'description',
            thing_history_translations.description
          )
        );
    SQL

    execute <<-SQL.squish
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
    SQL

    execute <<-SQL.squish
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
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE thing_translations
      SET name = thing_translations.content->>'name',
        description = thing_translations.content->>'description';

      UPDATE thing_history_translations
      SET name = thing_history_translations.content->>'name',
        description = thing_history_translations.content->>'description';

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
