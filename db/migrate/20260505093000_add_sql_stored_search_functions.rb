# frozen_string_literal: true

class AddSqlStoredSearchFunctions < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.relative_date(value jsonb)
      RETURNS timestamptz
      LANGUAGE plpgsql
      STABLE PARALLEL SAFE
      SET search_path = public
      AS $$
      DECLARE
        distance integer;
        unit text;
        direction integer;
        offset_interval interval;
      BEGIN
        IF value IS NULL THEN
          RETURN NULL;
        END IF;

        distance := NULLIF(value->>'n', '')::integer;
        IF distance IS NULL THEN
          RETURN NULL;
        END IF;

        unit := COALESCE(value->>'unit', 'day');
        direction := CASE WHEN value->>'mode' = 'p' THEN 1 ELSE -1 END;

        offset_interval := CASE unit
          WHEN 'minute' THEN make_interval(mins => distance)
          WHEN 'hour' THEN make_interval(hours => distance)
          WHEN 'day' THEN make_interval(days => distance)
          WHEN 'week' THEN make_interval(days => distance * 7)
          WHEN 'month' THEN make_interval(months => distance)
          WHEN 'year' THEN make_interval(years => distance)
          ELSE make_interval(days => distance)
        END;

        RETURN now() + (direction * offset_interval);
      END;
      $$;

      CREATE OR REPLACE FUNCTION public.resolve_stored_search(search_id uuid)
      RETURNS SETOF uuid
      LANGUAGE plpgsql
      STABLE
      SET search_path = public
      AS $$
      DECLARE
        collection_type text;
        cache_ttl_value integer;
        cache_updated_at timestamp without time zone;
        cache_valid boolean;
        fn_name text;
      BEGIN
        SELECT collections.type, collections.cache_ttl, collections.cache_updated_at
        INTO collection_type, cache_ttl_value, cache_updated_at
        FROM public.collections
        WHERE id = search_id;

        IF collection_type IS NULL THEN
          RETURN;
        END IF;

        IF collection_type = 'DataCycleCore::WatchList' THEN
          RETURN QUERY
            SELECT thing_id
            FROM public.watch_list_data_hashes
            WHERE watch_list_id = search_id;
          RETURN;
        END IF;

        IF collection_type <> 'DataCycleCore::StoredFilter' THEN
          RETURN;
        END IF;

        /* Cache validity window mirrors Ruby Cachable#cached_result?: ttl + 10 min grace (CACHE_VALIDITY_GRACE_MINUTES). Keep the two in sync. */
        cache_valid := cache_ttl_value IS NOT NULL
          AND cache_ttl_value > 0
          AND cache_updated_at IS NOT NULL
          AND cache_updated_at >= (now() - ((cache_ttl_value + 10) * INTERVAL '1 minute'));

        IF cache_valid THEN
          RETURN QUERY
            SELECT thing_id
            FROM public.stored_filter_caches
            WHERE stored_filter_id = search_id;
          RETURN;
        END IF;

        fn_name := 'stored_filter_' || replace(search_id::text, '-', '_');

        BEGIN
          RETURN QUERY EXECUTE format('SELECT * FROM public.%I()', fn_name);
        EXCEPTION WHEN undefined_function THEN
          /* The per-filter SQL representation has not been synced yet (or was dropped): treat a missing function as an empty result set rather than raising. */
          RETURN;
        END;
      END;
      $$;

      COMMENT ON FUNCTION public.resolve_stored_search(uuid) IS 'Resolves a watch list or stored filter to its set of thing ids (watch list contents, fresh cache, live per-filter function, or empty when unknown/unsynced). Consume it with a SEMI-JOIN, e.g. "WHERE t.id IN (SELECT public.resolve_stored_search(:id))" or "JOIN public.resolve_stored_search(:id) AS res(id) ON res.id = t.id" - never as "t.id = ANY(array_agg(...))": the array form forces a full scan of things, whereas a semi-join lets the planner drive from the (usually small) resolved set and probe things by primary key.';
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP FUNCTION IF EXISTS public.resolve_stored_search(uuid);
      DROP FUNCTION IF EXISTS public.relative_date(jsonb);
    SQL
  end
end
