# frozen_string_literal: true

class AddFunctionForToHistory < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE
      OR REPLACE FUNCTION update_previous_thing_history (content_id UUID, current_locale VARCHAR) RETURNS TIMESTAMP WITH TIME ZONE LANGUAGE PLPGSQL AS $$
        DECLARE
          previous_history record = NULL;
          current_thing record = NULL;
          end_time TIMESTAMP WITH TIME ZONE;
          start_time TIMESTAMP WITH TIME ZONE;
        BEGIN
          SELECT
            thing_histories.id,
            thing_histories.thing_id,
            thing_histories.created_at,
            thing_history_translations.locale,
            thing_history_translations.history_valid INTO previous_history
          FROM
            thing_histories
            INNER JOIN thing_history_translations ON thing_history_translations.locale = 'de'
            AND thing_history_translations.thing_history_id = thing_histories.id
          WHERE
            UPPER(thing_history_translations.history_valid) IS NULL
            AND thing_histories.thing_id = content_id
          LIMIT
            1;

          SELECT
            things.* INTO current_thing
          FROM
            things
          WHERE
            things.id = content_id
          LIMIT
            1;

          IF previous_history IS NOT NULL THEN
            SELECT
              GREATEST(LOWER(previous_history.history_valid), previous_history.created_at::TIMESTAMP WITH TIME ZONE) INTO start_time;

            SELECT
              (
                CASE
                  WHEN start_time >= current_thing.updated_at::TIMESTAMP WITH TIME ZONE THEN current_thing.updated_at::TIMESTAMP WITH TIME ZONE + INTERVAL '1 millisecond'
                  ELSE current_thing.updated_at::TIMESTAMP WITH TIME ZONE
                END
              ) INTO end_time;

            UPDATE thing_history_translations
            SET
              history_valid = tstzrange (start_time, end_time, '[)')
            WHERE
              thing_history_translations.thing_history_id = previous_history.id
              AND thing_history_translations.locale = previous_history.locale;
          ELSE
            SELECT
              current_thing.updated_at::TIMESTAMP WITH TIME ZONE INTO end_time;
          END IF;

          RETURN end_time;
        END;
      $$;

      CREATE
      OR REPLACE FUNCTION to_thing_history_translation (content_id UUID, new_history_id UUID, current_locale VARCHAR, all_translations BOOLEAN, new_end_time TIMESTAMP WITH TIME ZONE) RETURNS SETOF UUID LANGUAGE PLPGSQL AS $$
        DECLARE
        BEGIN
          RETURN QUERY INSERT INTO
            thing_history_translations(thing_history_id, locale, content, name, description, slug, created_at, updated_at, history_valid)
          SELECT
            new_history_id AS thing_history_id,
            thing_translations.locale,
            thing_translations.content,
            thing_translations.name,
            thing_translations.description,
            thing_translations.slug,
            new_end_time AS created_at,
            new_end_time AS updated_at,
            tstzrange (new_end_time, NULL, '[)') AS history_valid
          FROM
            thing_translations
          WHERE
            thing_translations.thing_id = content_id
            AND (
              CASE
                WHEN all_translations THEN thing_translations.locale IS NOT NULL
                ELSE thing_translations.locale = current_locale
              END
            )
          RETURNING
            id;
        END;
      $$;

      CREATE
      OR REPLACE FUNCTION to_classification_content_history (content_id UUID, new_history_id UUID, new_end_time TIMESTAMP WITH TIME ZONE) RETURNS SETOF UUID LANGUAGE PLPGSQL AS $$
        DECLARE
        BEGIN
          RETURN QUERY INSERT INTO
            classification_content_histories(content_data_history_id, classification_id, seen_at, relation, created_at, updated_at)
          SELECT
            new_history_id AS content_data_history_id,
            classification_contents.classification_id,
            classification_contents.seen_at,
            classification_contents.relation,
            new_end_time AS created_at,
            new_end_time AS updated_at
          FROM
            classification_contents
          WHERE
            classification_contents.content_data_id = content_id
          RETURNING
            id;
        END;
      $$;

      CREATE
      OR REPLACE FUNCTION to_content_content_history (content_id UUID, new_history_id UUID, current_locale VARCHAR, all_translations BOOLEAN, new_end_time TIMESTAMP WITH TIME ZONE, deleted BOOLEAN) RETURNS SETOF UUID LANGUAGE PLPGSQL AS $$
        DECLARE
        BEGIN
          INSERT INTO
            content_content_histories(content_a_history_id, relation_a, content_b_history_id, content_b_history_type, order_a, relation_b, created_at, updated_at, history_valid)
          SELECT
            new_history_id AS content_a_history_id,
            content_contents.relation_a,
            content_contents.content_b_id AS content_b_history_id,
            'DataCycleCore::Thing' AS content_b_history_type,
            content_contents.order_a,
            content_contents.relation_b,
            new_end_time AS created_at,
            new_end_time AS updated_at,
            tstzrange (new_end_time, NULL, '[)') AS history_valid
          FROM
            content_contents
            INNER JOIN things ON things.id = content_contents.content_b_id
          WHERE
            content_contents.content_a_id = content_id
            AND things.content_type != 'embedded';

          RETURN QUERY INSERT INTO
            content_content_histories(content_a_history_id, relation_a, content_b_history_id, content_b_history_type, order_a, relation_b, created_at, updated_at, history_valid)
          SELECT
            new_history_id AS content_a_history_id,
            content_contents.relation_a,
            to_thing_history (content_contents.content_b_id, current_locale, all_translations, deleted) AS content_b_history_id,
            'DataCycleCore::Thing::History' AS content_b_history_type,
            content_contents.order_a,
            content_contents.relation_b,
            new_end_time AS created_at,
            new_end_time AS updated_at,
            tstzrange (new_end_time, NULL, '[)') AS history_valid
          FROM
            content_contents
            INNER JOIN things ON things.id = content_contents.content_b_id
          WHERE
            content_contents.content_a_id = content_id
            AND things.content_type = 'embedded'
          RETURNING
            id;
        END;
      $$;

      CREATE
      OR REPLACE FUNCTION to_schedule_history (content_id UUID, new_history_id UUID, new_end_time TIMESTAMP WITH TIME ZONE) RETURNS SETOF UUID LANGUAGE PLPGSQL AS $$
        DECLARE
        BEGIN
          RETURN QUERY INSERT INTO
            schedule_histories(thing_history_id, relation, dtstart, dtend, duration, rrule, rdate, exdate, external_source_id, external_key, seen_at, holidays, created_at, updated_at)
          SELECT
            new_history_id AS thing_history_id,
            schedules.relation,
            schedules.dtstart,
            schedules.dtend,
            schedules.duration,
            schedules.rrule,
            schedules.rdate,
            schedules.exdate,
            schedules.external_source_id,
            schedules.external_key,
            schedules.seen_at,
            schedules.holidays,
            new_end_time AS created_at,
            new_end_time AS updated_at
          FROM
            schedules
          WHERE
            schedules.thing_id = content_id
          RETURNING
            id;
        END;
      $$;

      CREATE
      OR REPLACE FUNCTION to_thing_history (content_id UUID, current_locale VARCHAR, all_translations BOOLEAN, deleted BOOLEAN) RETURNS UUID LANGUAGE PLPGSQL AS $$
        DECLARE
          new_end_time TIMESTAMP WITH TIME ZONE;
          new_history_id UUID;
        BEGIN
          SELECT
            update_previous_thing_history (content_id, current_locale) INTO new_end_time;

          INSERT INTO
            thing_histories(thing_id, metadata, template_name, schema, template, internal_name, external_source_id, external_key, created_by, updated_by, deleted_by, cache_valid_since, created_at, updated_at, deleted_at, given_name, family_name, start_date, end_date, longitude, latitude, elevation, location, address_locality, street_address, postal_code, address_country, fax_number, telephone, email, is_part_of, validity_range, boost, content_type, representation_of_id, version_name, line, last_updated_locale)
          SELECT
            things.id AS thing_id,
            things.metadata,
            things.template_name,
            things.schema,
            things.template,
            things.internal_name,
            things.external_source_id,
            things.external_key,
            things.created_by,
            things.updated_by,
            things.deleted_by,
            things.cache_valid_since,
            new_end_time AS created_at,
            new_end_time AS updated_at,
            CASE
              WHEN deleted THEN new_end_time
              ELSE NULL
            END AS deleted_at,
            things.given_name,
            things.family_name,
            things.start_date,
            things.end_date,
            things.longitude,
            things.latitude,
            things.elevation,
            things.location,
            things.address_locality,
            things.street_address,
            things.postal_code,
            things.address_country,
            things.fax_number,
            things.telephone,
            things.email,
            things.is_part_of,
            things.validity_range,
            things.boost,
            things.content_type,
            things.representation_of_id,
            things.version_name,
            things.line,
            things.last_updated_locale
          FROM
            things
          WHERE
            things.id = content_id
          LIMIT
            1
          RETURNING
            id
          INTO new_history_id;

          PERFORM to_thing_history_translation (content_id, new_history_id, current_locale, all_translations, new_end_time);
          PERFORM to_classification_content_history (content_id, new_history_id, new_end_time);
          PERFORM to_content_content_history (content_id, new_history_id, current_locale, all_translations, new_end_time, deleted);
          PERFORM to_schedule_history (content_id, new_history_id, new_end_time);

          RETURN new_history_id;
        END;
      $$;
    SQL
  end

  def down
  end
end
