SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_phash; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_phash WITH SCHEMA public;


--
-- Name: EXTENSION pg_phash; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_phash IS 'support phash hamming distance calculation';


--
-- Name: pg_rrule; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_rrule WITH SCHEMA public;


--
-- Name: EXTENSION pg_rrule; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_rrule IS 'RRULE field type for PostgreSQL';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: delete_ca_paths_transitive_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_ca_paths_transitive_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY[OLD.classification_alias_id]::uuid[]); RETURN NEW; END; $$;


--
-- Name: delete_ccc_relations_transitive_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_ccc_relations_transitive_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (ARRAY[OLD.content_data_id]::uuid[], ARRAY[OLD.classification_id]::uuid[]); RETURN NEW; END; $$;


--
-- Name: delete_ccc_relations_transitive_trigger_2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_ccc_relations_transitive_trigger_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (ARRAY_AGG(content_data_id), ARRAY[]::uuid[]) FROM ( SELECT DISTINCT classification_contents.content_data_id FROM old_classification_alias_paths_transitive INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY (old_classification_alias_paths_transitive.full_path_ids) AND classification_groups.deleted_at IS NULL INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id) "collected_classification_content_relations_alias"; RETURN NULL; END; $$;


--
-- Name: delete_collected_classification_content_relations_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_collected_classification_content_relations_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_classification_content_relations ( (SELECT ARRAY_AGG(DISTINCT things.id) FROM things JOIN classification_contents ON things.id = classification_contents.content_data_id JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL WHERE classification_groups.classification_id = OLD.classification_id), ARRAY[]::uuid[]); RETURN NEW; END; $$;


--
-- Name: delete_content_content_links(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_content_content_links(a uuid, b uuid) RETURNS uuid[]
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM content_content_links WHERE content_a_id = a AND content_b_id = b; RETURN ARRAY[a, b]; END;$$;


--
-- Name: delete_content_content_links_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_content_content_links_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE a_b INTEGER; DECLARE b_a INTEGER; BEGIN a_b := ( SELECT COUNT(*) FROM content_contents WHERE ( content_a_id = OLD.content_a_id AND content_b_id = OLD.content_b_id ) OR ( content_a_id = OLD.content_b_id AND content_b_id = OLD.content_a_id AND relation_b IS NOT NULL ) ); b_a := ( SELECT COUNT(*) FROM content_contents WHERE ( content_a_id = OLD.content_a_id AND content_b_id = OLD.content_b_id AND OLD.relation_b IS NOT NULL ) OR ( content_a_id = OLD.content_b_id AND content_b_id = OLD.content_a_id ) ); IF a_b = 1 THEN PERFORM delete_content_content_links(OLD.content_a_id, OLD.content_b_id); END IF; IF b_a = 1 THEN PERFORM delete_content_content_links(OLD.content_b_id, OLD.content_a_id); END IF; RETURN OLD; END;$$;


--
-- Name: delete_schedule_occurences(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_schedule_occurences(schedule_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM schedule_occurrences WHERE schedule_id = ANY (schedule_ids); END; $$;


--
-- Name: delete_schedule_occurences_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_schedule_occurences_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM delete_schedule_occurences (ARRAY_AGG(id)) FROM ( SELECT DISTINCT old_schedules.id FROM old_schedules) "old_schedules_alias"; RETURN NULL; END; $$;


--
-- Name: generate_ca_paths_transitive(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ca_paths_transitive(classification_alias_ids uuid[]) RETURNS SETOF uuid
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM classification_alias_paths_transitive WHERE full_path_ids && classification_alias_ids; RETURN QUERY WITH RECURSIVE paths ( id, ancestors_ids, full_path_ids, full_path_names, link_types ) AS ( SELECT ca1.id AS id, array_remove(ARRAY[ca2.id]::uuid[], NULL) AS ancestors_ids, array_remove(ARRAY[ca1.id, ca2.id]::uuid[], NULL) AS full_path_ids, array_remove(ARRAY[ca1.internal_name, ca2.internal_name, classification_tree_labels.name]::varchar[], NULL) AS full_path_names, ( CASE WHEN ca2.id IS NULL THEN ARRAY[]::text[] ELSE ARRAY[classification_alias_links.link_type]::text[] END) AS link_types FROM classification_alias_links JOIN classification_aliases ca1 ON ca1.id = classification_alias_links.child_classification_alias_id JOIN classification_trees ON classification_trees.classification_alias_id = ca1.id JOIN classification_tree_labels ON classification_tree_labels.id = classification_trees.classification_tree_label_id LEFT OUTER JOIN classification_aliases ca2 ON ca2.id = classification_alias_links.parent_classification_alias_id WHERE ca1.id = ANY (classification_alias_ids) AND classification_alias_links.link_type = 'broader' UNION ALL SELECT classification_aliases.id AS id, (classification_alias_links.parent_classification_alias_id || paths_1.ancestors_ids) AS ancestors_ids, (classification_aliases.id || paths_1.full_path_ids) AS full_path_ids, (classification_aliases.internal_name || paths_1.full_path_names) AS full_path_names, (classification_alias_links.link_type || paths_1.link_types) AS link_types FROM classification_alias_links JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id JOIN paths paths_1 ON paths_1.id = classification_alias_links.parent_classification_alias_id WHERE classification_aliases.id <> ALL (paths_1.full_path_ids)) INSERT INTO classification_alias_paths_transitive ( classification_alias_id, ancestor_ids, full_path_ids, full_path_names, link_types) SELECT DISTINCT paths.id, paths.ancestors_ids, paths.full_path_ids, paths.full_path_names, paths.link_types FROM paths RETURNING classification_alias_id; RETURN; END; $$;


--
-- Name: generate_ca_paths_transitive_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ca_paths_transitive_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY[NEW.id]::uuid[]); RETURN NEW; END; $$;


--
-- Name: generate_ca_paths_transitive_trigger_2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ca_paths_transitive_trigger_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_ca_paths_transitive (NEW.parent_classification_alias_id || ARRAY[NEW.classification_alias_id]::uuid[]); RETURN NEW; END; $$;


--
-- Name: generate_ca_paths_transitive_trigger_3(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ca_paths_transitive_trigger_3() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY_AGG(classification_alias_id)) FROM ( SELECT classification_trees.classification_alias_id FROM classification_trees WHERE classification_trees.classification_tree_label_id = NEW.id) "classification_trees_alias"; RETURN NEW; END; $$;


--
-- Name: generate_ca_paths_transitive_trigger_4(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ca_paths_transitive_trigger_4() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY[NEW.classification_alias_id]::uuid[]); RETURN NEW; END; $$;


--
-- Name: generate_ccc_relations_transitive_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ccc_relations_transitive_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (ARRAY_AGG(content_data_id), ARRAY[]::uuid[]) FROM ( SELECT DISTINCT classification_contents.content_data_id FROM new_classification_alias_paths_transitive INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY (new_classification_alias_paths_transitive.full_path_ids) AND classification_groups.deleted_at IS NULL INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id) "collected_classification_content_relations_alias"; RETURN NULL; END; $$;


--
-- Name: generate_ccc_relations_transitive_trigger_2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ccc_relations_transitive_trigger_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (ARRAY[NEW.content_data_id]::uuid[], ARRAY[]::uuid[]); RETURN NEW; END; $$;


--
-- Name: generate_classification_alias_paths(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_classification_alias_paths(classification_alias_ids uuid[]) RETURNS uuid[]
    LANGUAGE plpgsql
    AS $$ DECLARE classification_alias_path_ids UUID[]; BEGIN DELETE FROM classification_alias_paths WHERE id = ANY(classification_alias_ids); WITH RECURSIVE paths( id, parent_id,ancestor_ids,full_path_ids,full_path_names, tree_label_id) AS ( SELECT classification_aliases.id, classification_trees.parent_classification_alias_id, ARRAY[]::uuid[], ARRAY[classification_aliases.id], ARRAY[classification_aliases.internal_name], classification_trees.classification_tree_label_id FROM classification_trees JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id WHERE classification_trees.classification_alias_id = ANY(classification_alias_ids) UNION ALL SELECT paths.id, classification_trees.parent_classification_alias_id, ancestor_ids || classification_aliases.id, full_path_ids || classification_aliases.id , full_path_names || classification_aliases.internal_name, classification_trees.classification_tree_label_id FROM classification_trees JOIN paths ON paths.parent_id = classification_trees.classification_alias_id JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id ) INSERT INTO classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names) SELECT paths.id, paths.ancestor_ids, paths.full_path_ids, paths.full_path_names || classification_tree_labels.name FROM paths JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id WHERE paths.parent_id IS NULL; SELECT ARRAY_AGG(id) INTO classification_alias_path_ids FROM classification_alias_paths WHERE id = ANY(classification_alias_ids); RETURN classification_alias_path_ids; END;$$;


--
-- Name: generate_classification_alias_paths_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_classification_alias_paths_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_classification_alias_paths (array_agg(id) || ARRAY[NEW.id]::UUID[]) FROM ( SELECT id FROM classification_alias_paths WHERE NEW.id = ANY (ancestor_ids)) "new_child_classification_aliases"; RETURN NEW; END; $$;


--
-- Name: generate_classification_alias_paths_trigger_2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_classification_alias_paths_trigger_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_classification_alias_paths (array_agg(id) || ARRAY[NEW.classification_alias_id]::UUID[]) FROM ( SELECT id FROM classification_alias_paths WHERE NEW.classification_alias_id = ANY (ancestor_ids)) "changed_child_classification_aliases"; RETURN NEW; END; $$;


--
-- Name: generate_classification_alias_paths_trigger_3(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_classification_alias_paths_trigger_3() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_classification_alias_paths (array_agg(classification_alias_id)) FROM ( SELECT classification_alias_id FROM classification_trees WHERE classification_trees.classification_tree_label_id = NEW.id) "changed_tree_classification_aliases"; RETURN NEW; END; $$;


--
-- Name: generate_collected_cl_content_relations_transitive(uuid[], uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_cl_content_relations_transitive(content_ids uuid[], excluded_classification_ids uuid[]) RETURNS SETOF uuid
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM collected_classification_content_relations WHERE content_id IN ( SELECT cccr.content_id FROM collected_classification_content_relations cccr WHERE cccr.content_id = ANY (content_ids) ORDER BY cccr.content_id ASC FOR UPDATE SKIP LOCKED ); RETURN QUERY WITH direct_classification_content_relations AS ( SELECT DISTINCT classification_contents.content_data_id "thing_id", classification_groups.classification_alias_id "classification_alias_id" FROM classification_contents JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL WHERE classification_contents.content_data_id = ANY (content_ids) AND classification_contents.classification_id <> ALL (excluded_classification_ids) ), full_classification_content_relations AS ( SELECT DISTINCT classification_contents.content_data_id "thing_id", classification_alias_paths_transitive.full_path_ids "classification_alias_id" FROM classification_contents JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id WHERE classification_contents.content_data_id = ANY (content_ids) AND classification_contents.classification_id <> ALL (excluded_classification_ids)) INSERT INTO collected_classification_content_relations ( content_id, direct_classification_alias_ids, full_classification_alias_ids) SELECT things.id "content_id", direct_content_classification_ids "direct_classification_alias_ids", full_content_classification_ids "full_classification_alias_ids" FROM things JOIN ( SELECT thing_id, ARRAY_AGG(DISTINCT direct_classification_content_relations.classification_alias_id) "direct_content_classification_ids" FROM direct_classification_content_relations GROUP BY thing_id) "direct_relations" ON direct_relations.thing_id = things.id JOIN ( SELECT t.thing_id, ARRAY_AGG(t.classification_alias_id) "full_content_classification_ids" FROM ( SELECT DISTINCT unnest(full_classification_content_relations.classification_alias_id) AS classification_alias_id, full_classification_content_relations.thing_id AS thing_id FROM full_classification_content_relations) t GROUP BY t.thing_id) "full_relations" ON full_relations.thing_id = things.id RETURNING content_id; RETURN; END; $$;


--
-- Name: generate_collected_classification_content_relations(uuid[], uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_classification_content_relations(content_ids uuid[], excluded_classification_ids uuid[]) RETURNS uuid[]
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM collected_classification_content_relations WHERE content_id IN ( SELECT cccr.content_id FROM collected_classification_content_relations cccr WHERE cccr.content_id = ANY (content_ids) ORDER BY cccr.content_id ASC FOR UPDATE SKIP LOCKED ); WITH direct_classification_content_relations AS ( SELECT DISTINCT things.id "thing_id", classification_groups.classification_alias_id "classification_alias_id" FROM things JOIN classification_contents ON things.id = classification_contents.content_data_id JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL WHERE things.id = ANY (content_ids) AND classification_contents.classification_id <> ALL (excluded_classification_ids) ), full_classification_content_relations AS ( SELECT DISTINCT things.id "thing_id", UNNEST(classification_alias_paths.full_path_ids) "classification_alias_id" FROM things JOIN classification_contents ON things.id = classification_contents.content_data_id JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id WHERE things.id = ANY (content_ids) AND classification_contents.classification_id <> ALL (excluded_classification_ids)) INSERT INTO collected_classification_content_relations (content_id, direct_classification_alias_ids, full_classification_alias_ids) SELECT things.id "content_id", direct_content_classification_ids "direct_classification_alias_ids", full_content_classification_ids "full_classification_alias_ids" FROM things JOIN ( SELECT thing_id, ARRAY_AGG(direct_classification_content_relations.classification_alias_id) "direct_content_classification_ids" FROM direct_classification_content_relations GROUP BY thing_id) "direct_relations" ON direct_relations.thing_id = things.id JOIN ( SELECT thing_id, ARRAY_AGG(full_classification_content_relations.classification_alias_id) "full_content_classification_ids" FROM full_classification_content_relations GROUP BY thing_id) "full_relations" ON full_relations.thing_id = things.id; RETURN content_ids; END; $$;


--
-- Name: generate_collected_classification_content_relations_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_classification_content_relations_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_classification_content_relations(ARRAY[NEW.content_data_id]::UUID[], ARRAY[]::UUID[]); RETURN NEW; END;$$;


--
-- Name: generate_collected_classification_content_relations_trigger_2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_classification_content_relations_trigger_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_classification_content_relations( ARRAY[OLD.content_data_id]::UUID[], ARRAY[OLD.classification_id]::UUID[] ); RETURN NEW; END;$$;


--
-- Name: generate_collected_classification_content_relations_trigger_3(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_classification_content_relations_trigger_3() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_classification_content_relations (ARRAY_AGG(content_data_id), ARRAY[]::uuid[]) FROM ( SELECT DISTINCT classification_contents.content_data_id FROM classification_alias_paths INNER JOIN classification_groups ON classification_groups.classification_alias_id = classification_alias_paths.id AND classification_groups.deleted_at IS NULL INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id WHERE classification_alias_paths.full_path_ids && ARRAY[NEW.id]::uuid[]) "relevant_content_ids"; RETURN NEW; END; $$;


--
-- Name: generate_collected_classification_content_relations_trigger_4(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_classification_content_relations_trigger_4() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_classification_content_relations ( (SELECT ARRAY_AGG(DISTINCT things.id) FROM things JOIN classification_contents ON things.id = classification_contents.content_data_id JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL WHERE classification_groups.classification_id = NEW.classification_id), ARRAY[]::uuid[]); RETURN NEW; END; $$;


--
-- Name: generate_content_content_links(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_content_content_links(a uuid, b uuid) RETURNS uuid[]
    LANGUAGE plpgsql
    AS $$ BEGIN INSERT INTO content_content_links (content_a_id, content_b_id) SELECT content_a_id, content_b_id FROM content_contents WHERE content_a_id = a AND content_b_id = b ON CONFLICT DO NOTHING; INSERT INTO content_content_links (content_a_id, content_b_id) SELECT content_b_id, content_a_id FROM content_contents WHERE content_a_id = a AND content_b_id = b AND relation_b IS NOT NULL ON CONFLICT DO NOTHING; RETURN ARRAY[a, b]; END;$$;


--
-- Name: generate_content_content_links_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_content_content_links_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_content_content_links(NEW.content_a_id, NEW.content_b_id); RETURN NEW; END;$$;


--
-- Name: generate_my_selection_watch_list(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_my_selection_watch_list() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF EXISTS ( SELECT FROM roles WHERE roles.id = NEW.role_id AND roles.rank <> 0) THEN INSERT INTO watch_lists ( name, user_id, created_at, updated_at, full_path, full_path_names, my_selection) SELECT 'Meine Auswahl', users.id, NOW(), NOW(), 'Meine Auswahl', ARRAY[]::varchar[], TRUE FROM users INNER JOIN roles ON roles.id = users.role_id WHERE users.id = NEW.id AND roles.rank <> 0 AND NOT EXISTS ( SELECT FROM watch_lists WHERE watch_lists.my_selection AND watch_lists.user_id = users.id); ELSE DELETE FROM watch_lists WHERE watch_lists.user_id = NEW.id AND watch_lists.my_selection; END IF; RETURN NEW; END; $$;


--
-- Name: generate_schedule_occurences(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_schedule_occurences(schedule_ids uuid[]) RETURNS SETOF uuid
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM schedule_occurrences WHERE schedule_id = ANY (schedule_ids); RETURN QUERY WITH occurences AS ( SELECT schedules.id, schedules.thing_id, CASE WHEN duration IS NULL THEN INTERVAL '1 seconds' WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds' ELSE duration END AS duration, unnest(get_occurrences (schedules.rrule::rrule, schedules.dtstart AT TIME ZONE 'Europe/Vienna')) AT TIME ZONE 'Europe/Vienna' AS occurence FROM schedules WHERE schedules.relation IS NOT NULL AND rrule LIKE '%UNTIL%' AND id = ANY (schedule_ids) UNION SELECT schedules.id, schedules.thing_id, CASE WHEN duration IS NULL THEN INTERVAL '1 seconds' WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds' ELSE duration END AS duration, unnest(get_occurrences ((schedules.rrule || ';UNTIL=2037-12-31')::rrule, schedules.dtstart AT TIME ZONE 'Europe/Vienna')) AT TIME ZONE 'Europe/Vienna' AS occurence FROM schedules WHERE schedules.relation IS NOT NULL AND rrule NOT LIKE '%UNTIL%' AND id = ANY (schedule_ids) UNION SELECT schedules.id, schedules.thing_id, CASE WHEN duration IS NULL THEN INTERVAL '1 seconds' WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds' ELSE duration END AS duration, schedules.dtstart AS occurence FROM schedules WHERE schedules.relation IS NOT NULL AND schedules.rrule IS NULL AND id = ANY (schedule_ids) UNION SELECT schedules.id, schedules.thing_id, CASE WHEN duration IS NULL THEN INTERVAL '1 seconds' WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds' ELSE duration END AS duration, unnest(schedules.rdate) AS occurence FROM schedules WHERE schedules.relation IS NOT NULL AND id = ANY (schedule_ids)) INSERT INTO schedule_occurrences ( schedule_id, thing_id, duration, occurrence) SELECT occurences.id, occurences.thing_id, occurences.duration, tstzrange(occurences.occurence, occurences.occurence + occurences.duration) AS occurrence FROM occurences WHERE occurences.id = ANY (schedule_ids) AND NOT EXISTS ( SELECT 1 FROM ( SELECT id "schedule_id", UNNEST(exdate) "date" FROM schedules) "exdates" WHERE exdates.schedule_id = occurences.id AND tstzrange(DATE_TRUNC('day', exdates.date), DATE_TRUNC('day', exdates.date) + INTERVAL '1 day') && tstzrange(occurences.occurence, occurences.occurence + occurences.duration)) RETURNING id; RETURN; END; $$;


--
-- Name: generate_schedule_occurences_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_schedule_occurences_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_schedule_occurences(NEW.id || '{}'::UUID[]); RETURN NEW; END;$$;


--
-- Name: get_dict(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_dict(lang character varying) RETURNS regconfig
    LANGUAGE sql
    AS $$ SELECT pg_dict_mappings.dict::regconfig FROM pg_dict_mappings WHERE pg_dict_mappings.locale IN (lang, 'simple') LIMIT 1; $$;


--
-- Name: tsvectorsearchupdate(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tsvectorsearchupdate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
      	NEW.words := pg_catalog.to_tsvector(get_dict(NEW.locale), NEW.full_text::text);
        RETURN NEW;
      END;$$;


--
-- Name: update_template_definitions_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_template_definitions_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN UPDATE things SET "schema" = NEW.schema, boost = (NEW.schema -> 'boost')::numeric, content_type = NEW.schema ->> 'content_type', cache_valid_since = NOW() WHERE things.template_name = NEW.template_name AND things.template = FALSE; RETURN new; END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id uuid NOT NULL,
    blob_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blob_id uuid NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    activitiable_type character varying,
    activitiable_id uuid,
    user_id uuid,
    activity_type character varying,
    data jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: asset_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asset_contents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_data_id uuid,
    content_data_type character varying,
    asset_id uuid,
    asset_type character varying,
    relation character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    file character varying,
    type character varying,
    content_type character varying,
    file_size bigint,
    creator_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    seen_at timestamp without time zone,
    name character varying,
    metadata jsonb,
    duplicate_check jsonb
);


--
-- Name: classification_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    classification_id uuid,
    classification_alias_id uuid,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- Name: classification_trees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_trees (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_source_id uuid,
    parent_classification_alias_id uuid,
    classification_alias_id uuid,
    relationship_label character varying,
    classification_tree_label_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- Name: classification_alias_links; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.classification_alias_links AS
 WITH primary_classification_groups AS (
         SELECT DISTINCT classification_groups.classification_alias_id,
            first_value(classification_groups.classification_id) OVER (PARTITION BY classification_groups.classification_alias_id ORDER BY classification_groups.created_at) AS classification_id
           FROM public.classification_groups
          WHERE (classification_groups.deleted_at IS NULL)
        )
 SELECT additional_classification_groups.classification_alias_id AS parent_classification_alias_id,
    primary_classification_groups.classification_alias_id AS child_classification_alias_id,
    'related'::text AS link_type
   FROM (primary_classification_groups
     JOIN public.classification_groups additional_classification_groups ON (((primary_classification_groups.classification_id = additional_classification_groups.classification_id) AND (additional_classification_groups.classification_alias_id <> primary_classification_groups.classification_alias_id) AND (additional_classification_groups.deleted_at IS NULL))))
UNION
 SELECT classification_trees.parent_classification_alias_id,
    classification_trees.classification_alias_id AS child_classification_alias_id,
    'broader'::text AS link_type
   FROM public.classification_trees
  WHERE (classification_trees.deleted_at IS NULL);


--
-- Name: classification_alias_paths; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_alias_paths (
    id uuid NOT NULL,
    ancestor_ids uuid[],
    full_path_ids uuid[],
    full_path_names character varying[]
);


--
-- Name: classification_alias_paths_transitive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_alias_paths_transitive (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    classification_alias_id uuid NOT NULL,
    ancestor_ids uuid[],
    full_path_ids uuid[],
    full_path_names character varying[],
    link_types character varying[]
);


--
-- Name: classification_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    internal_name character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    internal boolean DEFAULT false,
    deleted_at timestamp without time zone,
    assignable boolean DEFAULT true,
    name_i18n jsonb DEFAULT '{}'::jsonb,
    description_i18n jsonb DEFAULT '{}'::jsonb,
    uri character varying
);


--
-- Name: classification_content_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_content_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_data_history_id uuid,
    classification_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    relation character varying
);


--
-- Name: classification_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_contents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_data_id uuid,
    classification_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    relation character varying
);


--
-- Name: classification_polygons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_polygons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    admin_level integer,
    classification_alias_id uuid,
    geom public.geometry(MultiPolygon,3035),
    geog public.geography(MultiPolygon,4326),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: classification_tree_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_tree_labels (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    internal boolean DEFAULT false,
    deleted_at timestamp without time zone,
    visibility character varying[] DEFAULT '{}'::character varying[],
    change_behaviour character varying[] DEFAULT '{trigger_webhooks,clear_cache}'::character varying[]
);


--
-- Name: classification_user_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_user_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    classification_id uuid,
    user_group_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: classifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    external_source_id uuid,
    external_key character varying,
    description character varying,
    seen_at timestamp without time zone,
    location public.geometry(Point,4326),
    bbox public.geometry(Polygon,4326),
    shape public.geometry(MultiPolygon,4326),
    external_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    uri character varying
);


--
-- Name: collected_classification_content_relations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collected_classification_content_relations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    content_id uuid,
    direct_classification_alias_ids uuid[],
    full_classification_alias_ids uuid[]
);


--
-- Name: things; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.things (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    metadata jsonb,
    template_name character varying,
    schema jsonb,
    template boolean DEFAULT false NOT NULL,
    internal_name character varying,
    external_source_id uuid,
    external_key character varying,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    cache_valid_since timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    given_name character varying,
    family_name character varying,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    longitude double precision,
    latitude double precision,
    elevation double precision,
    location public.geometry(Point,4326),
    address_locality character varying,
    street_address character varying,
    postal_code character varying,
    address_country character varying,
    fax_number character varying,
    telephone character varying,
    email character varying,
    is_part_of uuid,
    validity_range tstzrange,
    boost numeric,
    content_type character varying,
    representation_of_id uuid,
    version_name character varying,
    line public.geometry(MultiLineStringZ,4326),
    last_updated_locale character varying,
    write_history boolean DEFAULT false
);


--
-- Name: content_properties; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_properties AS
 SELECT things.id AS content_id,
    things.template_name AS content_template_name,
    properties.key AS property_name,
    properties.value AS property_definition
   FROM public.things,
    LATERAL jsonb_each((things.schema -> 'properties'::text)) properties(key, value);


--
-- Name: content_computed_properties; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_computed_properties AS
 SELECT content_properties.content_id,
    content_properties.content_template_name,
    content_properties.property_name,
    split_part(parameters.value, '.'::text, 1) AS compute_parameter_property_name
   FROM public.content_properties,
    LATERAL jsonb_array_elements_text(((content_properties.property_definition -> 'compute'::text) -> 'parameters'::text)) parameters(value)
  WHERE (content_properties.property_definition ? 'compute'::text);


--
-- Name: content_content_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_content_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_a_history_id uuid,
    relation_a character varying,
    content_b_history_id uuid,
    content_b_history_type character varying,
    history_valid tstzrange,
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    order_a integer,
    relation_b character varying
);


--
-- Name: content_content_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_content_links (
    content_a_id uuid,
    content_b_id uuid
);


--
-- Name: content_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_contents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_a_id uuid,
    relation_a character varying,
    content_b_id uuid,
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    order_a integer,
    relation_b character varying
);


--
-- Name: content_content_relations; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_content_relations AS
 SELECT e.content_b_id AS src,
    e.content_a_id AS dest
   FROM public.content_contents e
UNION ALL
 SELECT f.content_a_id AS src,
    f.content_b_id AS dest
   FROM public.content_contents f
  WHERE (f.relation_b IS NOT NULL);


--
-- Name: data_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    item_id uuid,
    item_type character varying,
    creator_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    permissions character varying,
    receiver_id uuid,
    comment text,
    valid_from timestamp without time zone,
    valid_until timestamp without time zone,
    asset_id uuid,
    locale character varying
);


--
-- Name: watch_list_data_hashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watch_list_data_hashes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    watch_list_id uuid,
    hashable_id uuid,
    hashable_type character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: content_items; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_items AS
 SELECT data_links.id AS data_link_id,
    watch_list_data_hashes.hashable_type AS content_type,
    watch_list_data_hashes.hashable_id AS content_id,
    data_links.creator_id,
    data_links.receiver_id
   FROM (public.data_links
     JOIN public.watch_list_data_hashes ON ((watch_list_data_hashes.watch_list_id = data_links.item_id)))
  WHERE ((data_links.item_type)::text = 'DataCycleCore::WatchList'::text)
UNION
 SELECT data_links.id AS data_link_id,
    data_links.item_type AS content_type,
    data_links.item_id AS content_id,
    data_links.creator_id,
    data_links.receiver_id
   FROM public.data_links
  WHERE ((data_links.item_type)::text <> 'DataCycleCore::WatchList'::text);


--
-- Name: content_meta_items; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_meta_items AS
 SELECT things.id,
    'DataCycleCore::Thing'::text AS content_type,
    things.template_name,
    things.schema,
    things.external_source_id,
    things.external_key,
    things.created_by,
    things.updated_by,
    things.deleted_by
   FROM public.things
  WHERE (things.template IS FALSE);


--
-- Name: content_property_dependencies; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_property_dependencies AS
 SELECT content_computed_properties.content_id,
    content_computed_properties.content_template_name,
    content_computed_properties.property_name,
    content_computed_properties.compute_parameter_property_name,
    things.id AS dependent_content_id,
    things.template_name AS dependent_content_template_name
   FROM ((public.things
     JOIN public.content_contents ON ((content_contents.content_b_id = things.id)))
     JOIN public.content_computed_properties ON (((content_computed_properties.content_id = content_contents.content_a_id) AND (content_computed_properties.compute_parameter_property_name = (content_contents.relation_a)::text))));


--
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delayed_jobs (
    id integer NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    handler text NOT NULL,
    last_error text,
    run_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_at timestamp without time zone,
    locked_by character varying,
    queue character varying,
    delayed_reference_id character varying,
    delayed_reference_type character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.delayed_jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.delayed_jobs_id_seq OWNED BY public.delayed_jobs.id;


--
-- Name: thing_duplicates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_duplicates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_id uuid,
    thing_duplicate_id uuid,
    method character varying,
    score double precision,
    false_positive boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: duplicate_candidates; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.duplicate_candidates AS
 SELECT thing_duplicates.thing_duplicate_id AS duplicate_id,
    thing_duplicates.thing_id AS original_id,
    thing_duplicates.score,
    thing_duplicates.id AS thing_duplicate_id,
    thing_duplicates.false_positive
   FROM public.thing_duplicates
UNION
 SELECT thing_duplicates.thing_id AS duplicate_id,
    thing_duplicates.thing_duplicate_id AS original_id,
    thing_duplicates.score,
    thing_duplicates.id AS thing_duplicate_id,
    thing_duplicates.false_positive
   FROM public.thing_duplicates;


--
-- Name: external_system_syncs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_system_syncs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    syncable_id uuid,
    external_system_id uuid,
    data jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status character varying,
    syncable_type character varying DEFAULT 'DataCycleCore::Thing'::character varying,
    last_sync_at timestamp without time zone,
    last_successful_sync_at timestamp without time zone,
    external_key character varying,
    sync_type character varying DEFAULT 'export'::character varying
);


--
-- Name: external_systems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_systems (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    config jsonb,
    credentials jsonb,
    default_options jsonb,
    data jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    identifier character varying,
    last_download timestamp without time zone,
    last_successful_download timestamp without time zone,
    last_import timestamp without time zone,
    last_successful_import timestamp without time zone,
    deactivated boolean DEFAULT false
);


--
-- Name: pg_dict_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pg_dict_mappings (
    locale character varying NOT NULL,
    dict character varying NOT NULL
);


--
-- Name: primary_classification_groups; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.primary_classification_groups AS
 SELECT DISTINCT ON (classification_groups.classification_id) classification_groups.id,
    classification_groups.classification_id,
    classification_groups.classification_alias_id,
    classification_groups.external_source_id,
    classification_groups.seen_at,
    classification_groups.created_at,
    classification_groups.updated_at,
    classification_groups.deleted_at
   FROM public.classification_groups
  ORDER BY classification_groups.classification_id, classification_groups.created_at;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    rank integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: schedule_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedule_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_history_id uuid,
    relation character varying,
    dtstart timestamp with time zone,
    dtend timestamp with time zone,
    duration interval,
    rrule character varying,
    rdate timestamp with time zone[] DEFAULT '{}'::timestamp with time zone[],
    exdate timestamp with time zone[] DEFAULT '{}'::timestamp with time zone[],
    external_source_id uuid,
    external_key character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    holidays boolean
);


--
-- Name: schedule_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedule_occurrences (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    schedule_id uuid NOT NULL,
    thing_id uuid NOT NULL,
    duration interval,
    occurrence tstzrange NOT NULL
);


--
-- Name: schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_id uuid,
    relation character varying,
    dtstart timestamp with time zone,
    dtend timestamp with time zone,
    duration interval,
    rrule character varying,
    rdate timestamp with time zone[] DEFAULT '{}'::timestamp with time zone[],
    exdate timestamp with time zone[] DEFAULT '{}'::timestamp with time zone[],
    external_source_id uuid,
    external_key character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    holidays boolean
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.searches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_data_id uuid,
    locale character varying,
    words tsvector,
    full_text text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    headline character varying,
    data_type character varying,
    classification_string character varying,
    validity_period tstzrange,
    all_text text,
    boost double precision DEFAULT 1.0 NOT NULL,
    schema_type character varying DEFAULT 'Thing'::character varying NOT NULL,
    advanced_attributes jsonb,
    classification_aliases_mapping uuid[],
    classification_ancestors_mapping uuid[],
    words_typeahead tsvector
);


--
-- Name: stored_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stored_filters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    user_id uuid,
    language character varying[],
    parameters jsonb,
    system boolean DEFAULT false,
    api boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    api_users text[],
    linked_stored_filter_id uuid,
    sort_parameters jsonb,
    classification_tree_labels uuid[]
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    subscribable_id uuid,
    subscribable_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: thing_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_id uuid NOT NULL,
    metadata jsonb,
    template_name character varying,
    schema jsonb,
    template boolean DEFAULT false NOT NULL,
    internal_name character varying,
    external_source_id uuid,
    external_key character varying,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    cache_valid_since timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    given_name character varying,
    family_name character varying,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    longitude double precision,
    latitude double precision,
    elevation double precision,
    location public.geometry(Point,4326),
    address_locality character varying,
    street_address character varying,
    postal_code character varying,
    address_country character varying,
    fax_number character varying,
    telephone character varying,
    email character varying,
    is_part_of uuid,
    validity_range tstzrange,
    boost numeric,
    content_type character varying,
    representation_of_id uuid,
    version_name character varying,
    line public.geometry(MultiLineStringZ,4326),
    last_updated_locale character varying
);


--
-- Name: thing_history_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_history_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_history_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    name character varying,
    description text,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    slug character varying
);


--
-- Name: thing_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    name character varying,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    slug character varying
);


--
-- Name: timeseries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.timeseries (
    thing_id uuid NOT NULL,
    property character varying NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    value double precision,
    created_at timestamp(6) without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT transaction_timestamp() NOT NULL
);


--
-- Name: user_group_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_group_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_group_id uuid,
    user_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    given_name character varying DEFAULT ''::character varying NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    family_name character varying DEFAULT ''::character varying NOT NULL,
    locked_at timestamp without time zone,
    external boolean DEFAULT false NOT NULL,
    role_id uuid,
    notification_frequency character varying DEFAULT 'always'::character varying,
    access_token character varying,
    type character varying DEFAULT 'DataCycleCore::User'::character varying,
    name character varying,
    default_locale character varying DEFAULT 'de'::character varying,
    provider character varying,
    uid character varying,
    jti character varying,
    creator_id uuid,
    additional_attributes jsonb,
    confirmation_token character varying,
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    unconfirmed_email character varying,
    ui_locale character varying DEFAULT 'de'::character varying NOT NULL
);


--
-- Name: watch_list_shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watch_list_shares (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    shareable_id uuid,
    watch_list_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    shareable_type character varying DEFAULT 'DataCycleCore::UserGroup'::character varying
);


--
-- Name: watch_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watch_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    user_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    full_path character varying,
    full_path_names character varying[],
    my_selection boolean DEFAULT false NOT NULL
);


--
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs ALTER COLUMN id SET DEFAULT nextval('public.delayed_jobs_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: asset_contents asset_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_contents
    ADD CONSTRAINT asset_contents_pkey PRIMARY KEY (id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: classification_alias_paths classification_alias_paths_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_alias_paths
    ADD CONSTRAINT classification_alias_paths_pkey PRIMARY KEY (id);


--
-- Name: classification_alias_paths_transitive classification_alias_paths_transitive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_alias_paths_transitive
    ADD CONSTRAINT classification_alias_paths_transitive_pkey PRIMARY KEY (id);


--
-- Name: classification_content_histories classification_content_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_content_histories
    ADD CONSTRAINT classification_content_histories_pkey PRIMARY KEY (id);


--
-- Name: classification_contents classification_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_contents
    ADD CONSTRAINT classification_contents_pkey PRIMARY KEY (id);


--
-- Name: classification_polygons classification_polygons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_polygons
    ADD CONSTRAINT classification_polygons_pkey PRIMARY KEY (id);


--
-- Name: classification_user_groups classification_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_user_groups
    ADD CONSTRAINT classification_user_groups_pkey PRIMARY KEY (id);


--
-- Name: classification_aliases classifications_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_aliases
    ADD CONSTRAINT classifications_aliases_pkey PRIMARY KEY (id);


--
-- Name: classification_groups classifications_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_groups
    ADD CONSTRAINT classifications_groups_pkey PRIMARY KEY (id);


--
-- Name: classifications classifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classifications
    ADD CONSTRAINT classifications_pkey PRIMARY KEY (id);


--
-- Name: classification_tree_labels classifications_trees_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_tree_labels
    ADD CONSTRAINT classifications_trees_labels_pkey PRIMARY KEY (id);


--
-- Name: classification_trees classifications_trees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_trees
    ADD CONSTRAINT classifications_trees_pkey PRIMARY KEY (id);


--
-- Name: content_content_histories content_content_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_content_histories
    ADD CONSTRAINT content_content_histories_pkey PRIMARY KEY (id);


--
-- Name: content_contents content_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_contents
    ADD CONSTRAINT content_contents_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: data_links edit_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_links
    ADD CONSTRAINT edit_links_pkey PRIMARY KEY (id);


--
-- Name: external_systems external_systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_systems
    ADD CONSTRAINT external_systems_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schedule_histories schedule_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_histories
    ADD CONSTRAINT schedule_histories_pkey PRIMARY KEY (id);


--
-- Name: schedule_occurrences schedule_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_occurrences
    ADD CONSTRAINT schedule_occurrences_pkey PRIMARY KEY (id);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: searches searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searches
    ADD CONSTRAINT searches_pkey PRIMARY KEY (id);


--
-- Name: stored_filters stored_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stored_filters
    ADD CONSTRAINT stored_filters_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: thing_duplicates thing_duplicates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_duplicates
    ADD CONSTRAINT thing_duplicates_pkey PRIMARY KEY (id);


--
-- Name: external_system_syncs thing_external_systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_syncs
    ADD CONSTRAINT thing_external_systems_pkey PRIMARY KEY (id);


--
-- Name: thing_histories thing_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_histories
    ADD CONSTRAINT thing_histories_pkey PRIMARY KEY (id);


--
-- Name: thing_history_translations thing_history_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_history_translations
    ADD CONSTRAINT thing_history_translations_pkey PRIMARY KEY (id);


--
-- Name: thing_translations thing_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_translations
    ADD CONSTRAINT thing_translations_pkey PRIMARY KEY (id);


--
-- Name: things things_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.things
    ADD CONSTRAINT things_pkey PRIMARY KEY (id);


--
-- Name: user_group_users user_group_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group_users
    ADD CONSTRAINT user_group_users_pkey PRIMARY KEY (id);


--
-- Name: user_groups user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_groups
    ADD CONSTRAINT user_groups_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: watch_list_data_hashes watch_list_data_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watch_list_data_hashes
    ADD CONSTRAINT watch_list_data_hashes_pkey PRIMARY KEY (id);


--
-- Name: watch_list_shares watch_list_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watch_list_shares
    ADD CONSTRAINT watch_list_user_groups_pkey PRIMARY KEY (id);


--
-- Name: watch_lists watch_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watch_lists
    ADD CONSTRAINT watch_lists_pkey PRIMARY KEY (id);


--
-- Name: activities_data_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_data_id_idx ON public.activities USING btree (((data ->> 'id'::text)));


--
-- Name: all_text_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX all_text_idx ON public.searches USING gin (all_text public.gin_trgm_ops);


--
-- Name: by_content_relation_a; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_content_relation_a ON public.content_contents USING btree (content_a_id, relation_a, content_b_id);


--
-- Name: by_created_by_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_created_by_created_at ON public.things USING btree (created_by, created_at);


--
-- Name: by_ctl_esi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_ctl_esi ON public.classification_tree_labels USING btree (external_source_id);


--
-- Name: by_external_connection_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_external_connection_and_type ON public.external_system_syncs USING btree (external_system_id, external_key, sync_type);


--
-- Name: by_external_source_id_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_external_source_id_external_key ON public.schedules USING btree (external_source_id, external_key);


--
-- Name: by_external_system_id_syncable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_external_system_id_syncable_id ON public.external_system_syncs USING btree (external_system_id, syncable_id);


--
-- Name: by_template_name_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_template_name_template ON public.things USING btree (template_name, template);


--
-- Name: by_thing_id_version_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_thing_id_version_name ON public.thing_histories USING btree (thing_id, version_name);


--
-- Name: by_watch_list_hashable; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_watch_list_hashable ON public.watch_list_data_hashes USING btree (watch_list_id, hashable_id, hashable_type);


--
-- Name: child_parent_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX child_parent_index ON public.classification_trees USING btree (classification_alias_id, parent_classification_alias_id);


--
-- Name: classification_alias_paths_full_path_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_alias_paths_full_path_ids ON public.classification_alias_paths USING gin (full_path_ids);


--
-- Name: classification_alias_paths_transitive_full_path_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_alias_paths_transitive_full_path_ids ON public.classification_alias_paths_transitive USING gin (full_path_ids);


--
-- Name: classification_content_data_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_content_data_history_id_idx ON public.classification_content_histories USING btree (content_data_history_id);


--
-- Name: classification_polygons_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_polygons_geom_idx ON public.classification_polygons USING gist (geom);


--
-- Name: classification_string_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_string_idx ON public.searches USING gin (classification_string public.gin_trgm_ops);


--
-- Name: classified_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classified_name_idx ON public.stored_filters USING btree (api, system, name);


--
-- Name: collected_classification_content_relations_content_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX collected_classification_content_relations_content_id ON public.collected_classification_content_relations USING btree (content_id);


--
-- Name: collected_classification_content_relations_direct_classificatio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX collected_classification_content_relations_direct_classificatio ON public.collected_classification_content_relations USING gin (direct_classification_alias_ids);


--
-- Name: collected_classification_content_relations_full_classification_; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX collected_classification_content_relations_full_classification_ ON public.collected_classification_content_relations USING gin (full_classification_alias_ids);


--
-- Name: content_b_history_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_b_history_idx ON public.content_content_histories USING btree (content_b_history_type, content_b_history_id);


--
-- Name: delayed_jobs_delayed_reference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_delayed_reference_id ON public.delayed_jobs USING btree (delayed_reference_id);


--
-- Name: delayed_jobs_delayed_reference_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_delayed_reference_type ON public.delayed_jobs USING btree (delayed_reference_type);


--
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_priority ON public.delayed_jobs USING btree (priority, run_at);


--
-- Name: delayed_jobs_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_queue ON public.delayed_jobs USING btree (queue);


--
-- Name: deleted_at_classification_alias_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_classification_alias_id_idx ON public.classification_trees USING btree (deleted_at, classification_alias_id);


--
-- Name: deleted_at_classification_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_classification_id_idx ON public.classification_groups USING btree (deleted_at, classification_id);


--
-- Name: deleted_at_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_id_idx ON public.classification_aliases USING btree (deleted_at, id);


--
-- Name: extid_extkey_del_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX extid_extkey_del_idx ON public.classifications USING btree (deleted_at, external_source_id, external_key);


--
-- Name: full_path_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX full_path_idx ON public.watch_lists USING gin (full_path public.gin_trgm_ops);


--
-- Name: headline_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX headline_idx ON public.searches USING gin (headline public.gin_trgm_ops);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_activities_on_activitiable_type_and_activitiable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activities_on_activitiable_type_and_activitiable_id ON public.activities USING btree (activitiable_type, activitiable_id);


--
-- Name: index_activities_on_activity_type_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activities_on_activity_type_and_updated_at ON public.activities USING btree (activity_type, updated_at);


--
-- Name: index_activities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activities_on_user_id ON public.activities USING btree (user_id);


--
-- Name: index_activities_on_user_id_activity_type_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activities_on_user_id_activity_type_created_at ON public.activities USING btree (user_id, activity_type, created_at);


--
-- Name: index_asset_contents_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_asset_contents_on_asset_id ON public.asset_contents USING btree (asset_id);


--
-- Name: index_asset_contents_on_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_asset_contents_on_content_data_id ON public.asset_contents USING btree (content_data_id);


--
-- Name: index_assets_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assets_on_creator_id ON public.assets USING btree (creator_id);


--
-- Name: index_assets_on_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assets_on_type ON public.assets USING btree (type);


--
-- Name: index_classification_alias_paths_on_ancestor_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_alias_paths_on_ancestor_ids ON public.classification_alias_paths USING gin (ancestor_ids);


--
-- Name: index_classification_aliases_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_aliases_on_deleted_at ON public.classification_aliases USING btree (deleted_at);


--
-- Name: index_classification_aliases_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_aliases_on_id ON public.classification_aliases USING btree (id);


--
-- Name: index_classification_content_histories_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_content_histories_on_classification_id ON public.classification_content_histories USING btree (classification_id);


--
-- Name: index_classification_contents_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_contents_on_classification_id ON public.classification_contents USING btree (classification_id, content_data_id);


--
-- Name: index_classification_contents_on_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_contents_on_content_data_id ON public.classification_contents USING btree (content_data_id);


--
-- Name: index_classification_contents_on_unique_constraint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_contents_on_unique_constraint ON public.classification_contents USING btree (content_data_id, classification_id, relation);


--
-- Name: index_classification_groups_on_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_classification_alias_id ON public.classification_groups USING btree (classification_alias_id);


--
-- Name: index_classification_groups_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_classification_id ON public.classification_groups USING btree (classification_id);


--
-- Name: index_classification_groups_on_classification_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_classification_id_and_created_at ON public.classification_groups USING btree (classification_id, created_at);


--
-- Name: index_classification_groups_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_deleted_at ON public.classification_groups USING btree (deleted_at);


--
-- Name: index_classification_groups_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_external_source_id ON public.classification_groups USING btree (external_source_id);


--
-- Name: index_classification_tree_labels_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_tree_labels_on_deleted_at ON public.classification_tree_labels USING btree (deleted_at);


--
-- Name: index_classification_tree_labels_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_tree_labels_on_id ON public.classification_tree_labels USING btree (id);


--
-- Name: index_classification_tree_labels_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_tree_labels_on_name ON public.classification_tree_labels USING btree (name);


--
-- Name: index_classification_trees_on_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_classification_alias_id ON public.classification_trees USING btree (classification_alias_id);


--
-- Name: index_classification_trees_on_classification_tree_label_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_classification_tree_label_id ON public.classification_trees USING btree (classification_tree_label_id);


--
-- Name: index_classification_trees_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_deleted_at ON public.classification_trees USING btree (deleted_at);


--
-- Name: index_classification_trees_on_parent_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_parent_classification_alias_id ON public.classification_trees USING btree (parent_classification_alias_id);


--
-- Name: index_classification_user_groups_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_user_groups_on_classification_id ON public.classification_user_groups USING btree (classification_id);


--
-- Name: index_classification_user_groups_on_user_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_user_groups_on_user_group_id ON public.classification_user_groups USING btree (user_group_id);


--
-- Name: index_classifications_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_on_deleted_at ON public.classifications USING btree (deleted_at);


--
-- Name: index_classifications_on_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_on_external_key ON public.classifications USING btree (external_key);


--
-- Name: index_classifications_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_on_external_source_id ON public.classifications USING btree (external_source_id);


--
-- Name: index_classifications_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classifications_on_id ON public.classifications USING btree (id);


--
-- Name: index_content_content_histories_on_content_a_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_content_histories_on_content_a_history_id ON public.content_content_histories USING btree (content_a_history_id);


--
-- Name: index_content_content_links_on_content_b_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_content_links_on_content_b_id ON public.content_content_links USING btree (content_b_id);


--
-- Name: index_content_contents_on_content_b_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_contents_on_content_b_id ON public.content_contents USING btree (content_b_id);


--
-- Name: index_contents_a_b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_contents_a_b ON public.content_content_links USING btree (content_a_id, content_b_id);


--
-- Name: index_data_links_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_asset_id ON public.data_links USING btree (asset_id);


--
-- Name: index_data_links_on_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_item_id ON public.data_links USING btree (item_id);


--
-- Name: index_data_links_on_item_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_item_type ON public.data_links USING btree (item_type);


--
-- Name: index_external_system_syncs_on_syncalbe_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_external_system_syncs_on_syncalbe_id_and_external_key ON public.external_system_syncs USING btree (syncable_id, external_key);


--
-- Name: index_external_system_syncs_on_unique_attributes; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_system_syncs_on_unique_attributes ON public.external_system_syncs USING btree (syncable_type, syncable_id, external_system_id, sync_type, external_key);


--
-- Name: index_external_systems_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_systems_on_id ON public.external_systems USING btree (id);


--
-- Name: index_occurrence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_occurrence ON public.schedule_occurrences USING gist (occurrence);


--
-- Name: index_roles_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_name ON public.roles USING btree (name);


--
-- Name: index_roles_on_rank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_rank ON public.roles USING btree (rank);


--
-- Name: index_schedule_histories_on_from_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_histories_on_from_to ON public.schedule_histories USING gist (tstzrange(dtstart, dtend, '[]'::text));


--
-- Name: index_schedule_histories_on_thing_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_histories_on_thing_history_id ON public.schedule_histories USING btree (thing_history_id);


--
-- Name: index_schedule_occurrences_on_schedule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_occurrences_on_schedule_id ON public.schedule_occurrences USING btree (schedule_id);


--
-- Name: index_schedule_occurrences_on_thing_id_occurrence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_occurrences_on_thing_id_occurrence ON public.schedule_occurrences USING btree (thing_id, occurrence);


--
-- Name: index_schedules_on_from_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedules_on_from_to ON public.schedules USING gist (tstzrange(dtstart, dtend, '[]'::text));


--
-- Name: index_schedules_on_relation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedules_on_relation ON public.schedules USING btree (relation);


--
-- Name: index_schedules_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedules_on_thing_id ON public.schedules USING btree (thing_id);


--
-- Name: index_searches_on_advanced_attributes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_advanced_attributes ON public.searches USING gin (advanced_attributes);


--
-- Name: index_searches_on_classification_aliases_mapping; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_classification_aliases_mapping ON public.searches USING gin (classification_aliases_mapping);


--
-- Name: index_searches_on_classification_ancestors_mapping; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_classification_ancestors_mapping ON public.searches USING gin (classification_ancestors_mapping);


--
-- Name: index_searches_on_content_data_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_searches_on_content_data_id_and_locale ON public.searches USING btree (content_data_id, locale);


--
-- Name: index_searches_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_locale ON public.searches USING btree (locale);


--
-- Name: index_searches_on_words; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_words ON public.searches USING gin (words);


--
-- Name: index_stored_filters_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stored_filters_on_updated_at ON public.stored_filters USING btree (updated_at);


--
-- Name: index_stored_filters_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stored_filters_on_user_id ON public.stored_filters USING btree (user_id);


--
-- Name: index_subscriptions_on_subscribable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_subscribable_id ON public.subscriptions USING btree (subscribable_id);


--
-- Name: index_subscriptions_on_subscribable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_subscribable_type ON public.subscriptions USING btree (subscribable_type);


--
-- Name: index_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_user_id ON public.subscriptions USING btree (user_id);


--
-- Name: index_thing_histories_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_histories_on_id ON public.thing_histories USING btree (id);


--
-- Name: index_thing_histories_on_representation_of_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_histories_on_representation_of_id ON public.thing_histories USING btree (representation_of_id);


--
-- Name: index_thing_histories_on_updated_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_histories_on_updated_by ON public.thing_histories USING btree (updated_by);


--
-- Name: index_thing_history_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_id_locale ON public.thing_history_translations USING btree (thing_history_id, locale);


--
-- Name: index_thing_history_translations_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_history_translations_on_id ON public.thing_history_translations USING btree (id);


--
-- Name: index_thing_history_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_translations_on_locale ON public.thing_history_translations USING btree (locale);


--
-- Name: index_thing_history_translations_on_thing_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_translations_on_thing_history_id ON public.thing_history_translations USING btree (thing_history_id);


--
-- Name: index_thing_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_id_locale ON public.thing_translations USING btree (thing_id, locale);


--
-- Name: index_thing_translations_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_translations_on_id ON public.thing_translations USING btree (id);


--
-- Name: index_thing_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_translations_on_locale ON public.thing_translations USING btree (locale);


--
-- Name: index_thing_translations_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_translations_on_slug ON public.thing_translations USING btree (slug);


--
-- Name: index_thing_translations_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_translations_on_thing_id ON public.thing_translations USING btree (thing_id);


--
-- Name: index_things_on_boost_updated_at_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_boost_updated_at_id ON public.things USING btree (boost, updated_at, id);


--
-- Name: index_things_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_content_type ON public.things USING btree (((schema ->> 'content_type'::text)));


--
-- Name: index_things_on_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_external_key ON public.things USING btree (external_key);


--
-- Name: index_things_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_things_on_external_source_id_and_external_key ON public.things USING btree (external_source_id, external_key);


--
-- Name: index_things_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_things_on_id ON public.things USING btree (id);


--
-- Name: index_things_on_is_part_of; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_is_part_of ON public.things USING btree (is_part_of);


--
-- Name: index_things_on_line_geography_cast; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_line_geography_cast ON public.things USING gist (public.geography(line));


--
-- Name: index_things_on_line_spatial; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_line_spatial ON public.things USING gist (line);


--
-- Name: index_things_on_location_geography_cast; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_location_geography_cast ON public.things USING gist (public.geography(location));


--
-- Name: index_things_on_location_spatial; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_location_spatial ON public.things USING gist (location);


--
-- Name: index_things_on_representation_of_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_representation_of_id ON public.things USING btree (representation_of_id);


--
-- Name: index_things_on_schema_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_schema_type ON public.things USING btree (((schema ->> 'schema_type'::text)));


--
-- Name: index_things_on_template_content_type_validity_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_template_content_type_validity_range ON public.things USING btree (id, template, content_type, validity_range, template_name);


--
-- Name: index_things_on_updated_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_updated_by ON public.things USING btree (updated_by);


--
-- Name: index_things_template_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_template_template_name_idx ON public.things USING btree (template, template_name);


--
-- Name: index_user_group_users_on_user_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_group_users_on_user_group_id ON public.user_group_users USING btree (user_group_id);


--
-- Name: index_user_group_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_group_users_on_user_id ON public.user_group_users USING btree (user_id);


--
-- Name: index_user_groups_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_groups_on_id ON public.user_groups USING btree (id);


--
-- Name: index_user_groups_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_groups_on_name ON public.user_groups USING btree (name);


--
-- Name: index_users_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_creator_id ON public.users USING btree (creator_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_id ON public.users USING btree (id);


--
-- Name: index_users_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_jti ON public.users USING btree (jti);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_validity_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_validity_range ON public.things USING gist (validity_range);


--
-- Name: index_watch_list_data_hashes_on_hashable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_hashable_id ON public.watch_list_data_hashes USING btree (hashable_id);


--
-- Name: index_watch_list_data_hashes_on_hashable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_hashable_type ON public.watch_list_data_hashes USING btree (hashable_type);


--
-- Name: index_watch_list_data_hashes_on_watch_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_watch_list_id ON public.watch_list_data_hashes USING btree (watch_list_id);


--
-- Name: index_watch_list_shares_on_watch_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_shares_on_watch_list_id ON public.watch_list_shares USING btree (watch_list_id);


--
-- Name: index_watch_lists_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_lists_on_id ON public.watch_lists USING btree (id);


--
-- Name: index_watch_lists_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_lists_on_user_id ON public.watch_lists USING btree (user_id);


--
-- Name: name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX name_idx ON public.classification_aliases USING gin (internal_name public.gin_trgm_ops);


--
-- Name: parent_child_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX parent_child_index ON public.classification_trees USING btree (parent_classification_alias_id, classification_alias_id);


--
-- Name: pg_dict_mappings_locale_dict_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pg_dict_mappings_locale_dict_idx ON public.pg_dict_mappings USING btree (locale, dict);


--
-- Name: thing_attribute_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX thing_attribute_timestamp_idx ON public.timeseries USING btree (thing_id, property, "timestamp");


--
-- Name: thing_translations_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX thing_translations_name_idx ON public.thing_translations USING gin (name public.gin_trgm_ops);


--
-- Name: unique_by_shareable; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_by_shareable ON public.watch_list_shares USING btree (shareable_id, shareable_type, watch_list_id);


--
-- Name: unique_duplicate_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_duplicate_index ON public.thing_duplicates USING btree (thing_id, thing_duplicate_id, method);


--
-- Name: unique_thing_duplicate_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_thing_duplicate_idx ON public.thing_duplicates USING btree (LEAST(thing_id, thing_duplicate_id), GREATEST(thing_id, thing_duplicate_id));


--
-- Name: user_group_users_on_user_id_user_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_group_users_on_user_id_user_group_id ON public.user_group_users USING btree (user_id, user_group_id);


--
-- Name: validity_period_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX validity_period_idx ON public.searches USING gist (validity_period);


--
-- Name: words_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_idx ON public.searches USING gin (full_text public.gin_trgm_ops);


--
-- Name: classification_alias_paths_transitive delete_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_ccc_relations_transitive_trigger AFTER DELETE ON public.classification_alias_paths_transitive REFERENCING OLD TABLE AS old_classification_alias_paths_transitive FOR EACH STATEMENT EXECUTE FUNCTION public.delete_ccc_relations_transitive_trigger_2();

ALTER TABLE public.classification_alias_paths_transitive DISABLE TRIGGER delete_ccc_relations_transitive_trigger;


--
-- Name: classification_contents delete_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_ccc_relations_transitive_trigger AFTER DELETE ON public.classification_contents FOR EACH ROW EXECUTE FUNCTION public.delete_ccc_relations_transitive_trigger_1();

ALTER TABLE public.classification_contents DISABLE TRIGGER delete_ccc_relations_transitive_trigger;


--
-- Name: classification_groups delete_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_ccc_relations_transitive_trigger AFTER DELETE ON public.classification_groups FOR EACH ROW EXECUTE FUNCTION public.delete_ca_paths_transitive_trigger_1();

ALTER TABLE public.classification_groups DISABLE TRIGGER delete_ccc_relations_transitive_trigger;


--
-- Name: classification_groups delete_collected_classification_content_relations_trigger_1; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_collected_classification_content_relations_trigger_1 AFTER DELETE ON public.classification_groups FOR EACH ROW EXECUTE FUNCTION public.delete_collected_classification_content_relations_trigger_1();


--
-- Name: content_contents delete_content_content_links_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_content_content_links_trigger BEFORE DELETE ON public.content_contents FOR EACH ROW EXECUTE FUNCTION public.delete_content_content_links_trigger();


--
-- Name: schedules delete_schedule_occurences_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_schedule_occurences_trigger AFTER DELETE ON public.schedules REFERENCING OLD TABLE AS old_schedules FOR EACH STATEMENT EXECUTE FUNCTION public.delete_schedule_occurences_trigger();


--
-- Name: classification_aliases generate_ca_paths_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_ca_paths_transitive_trigger AFTER INSERT ON public.classification_aliases FOR EACH ROW EXECUTE FUNCTION public.generate_ca_paths_transitive_trigger_1();


--
-- Name: classification_tree_labels generate_ca_paths_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_ca_paths_transitive_trigger AFTER INSERT ON public.classification_tree_labels FOR EACH ROW EXECUTE FUNCTION public.generate_ca_paths_transitive_trigger_3();


--
-- Name: classification_trees generate_ca_paths_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_ca_paths_transitive_trigger AFTER INSERT ON public.classification_trees FOR EACH ROW EXECUTE FUNCTION public.generate_ca_paths_transitive_trigger_2();


--
-- Name: classification_alias_paths_transitive generate_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_ccc_relations_transitive_trigger AFTER INSERT ON public.classification_alias_paths_transitive REFERENCING NEW TABLE AS new_classification_alias_paths_transitive FOR EACH STATEMENT EXECUTE FUNCTION public.generate_ccc_relations_transitive_trigger_1();

ALTER TABLE public.classification_alias_paths_transitive DISABLE TRIGGER generate_ccc_relations_transitive_trigger;


--
-- Name: classification_contents generate_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_ccc_relations_transitive_trigger AFTER INSERT ON public.classification_contents FOR EACH ROW EXECUTE FUNCTION public.generate_ccc_relations_transitive_trigger_2();

ALTER TABLE public.classification_contents DISABLE TRIGGER generate_ccc_relations_transitive_trigger;


--
-- Name: classification_groups generate_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_ccc_relations_transitive_trigger AFTER INSERT ON public.classification_groups FOR EACH ROW EXECUTE FUNCTION public.generate_ca_paths_transitive_trigger_4();

ALTER TABLE public.classification_groups DISABLE TRIGGER generate_ccc_relations_transitive_trigger;


--
-- Name: classification_aliases generate_classification_alias_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_classification_alias_paths_trigger AFTER INSERT ON public.classification_aliases FOR EACH ROW EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_1();


--
-- Name: classification_tree_labels generate_classification_alias_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_classification_alias_paths_trigger AFTER INSERT ON public.classification_tree_labels FOR EACH ROW EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_3();


--
-- Name: classification_trees generate_classification_alias_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_classification_alias_paths_trigger AFTER INSERT ON public.classification_trees FOR EACH ROW EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_2();


--
-- Name: classification_alias_paths generate_collected_classification_content_relations_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_collected_classification_content_relations_trigger AFTER INSERT OR UPDATE ON public.classification_alias_paths FOR EACH ROW EXECUTE FUNCTION public.generate_collected_classification_content_relations_trigger_3();


--
-- Name: classification_contents generate_collected_classification_content_relations_trigger_1; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_collected_classification_content_relations_trigger_1 AFTER INSERT ON public.classification_contents FOR EACH ROW EXECUTE FUNCTION public.generate_collected_classification_content_relations_trigger_1();


--
-- Name: classification_contents generate_collected_classification_content_relations_trigger_2; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_collected_classification_content_relations_trigger_2 AFTER DELETE ON public.classification_contents FOR EACH ROW EXECUTE FUNCTION public.generate_collected_classification_content_relations_trigger_2();


--
-- Name: classification_groups generate_collected_classification_content_relations_trigger_4; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_collected_classification_content_relations_trigger_4 AFTER INSERT ON public.classification_groups FOR EACH ROW EXECUTE FUNCTION public.generate_collected_classification_content_relations_trigger_4();


--
-- Name: content_contents generate_content_content_links_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_content_content_links_trigger AFTER INSERT ON public.content_contents FOR EACH ROW EXECUTE FUNCTION public.generate_content_content_links_trigger();


--
-- Name: users generate_my_selection_watch_list; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_my_selection_watch_list AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.generate_my_selection_watch_list();


--
-- Name: schedules generate_schedule_occurences_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_schedule_occurences_trigger AFTER INSERT ON public.schedules FOR EACH ROW EXECUTE FUNCTION public.generate_schedule_occurences_trigger();


--
-- Name: searches tsvectorsearchinsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsvectorsearchinsert BEFORE INSERT ON public.searches FOR EACH ROW EXECUTE FUNCTION public.tsvectorsearchupdate();


--
-- Name: searches tsvectorsearchupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsvectorsearchupdate BEFORE UPDATE OF words, locale, full_text ON public.searches FOR EACH ROW WHEN (((old.words IS DISTINCT FROM new.words) OR ((old.locale)::text IS DISTINCT FROM (new.locale)::text) OR (old.full_text IS DISTINCT FROM new.full_text))) EXECUTE FUNCTION public.tsvectorsearchupdate();


--
-- Name: searches tsvectortypeaheadsearchinsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsvectortypeaheadsearchinsert BEFORE INSERT ON public.searches FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('words_typeahead', 'pg_catalog.simple', 'full_text');


--
-- Name: searches tsvectortypeaheadsearchupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsvectortypeaheadsearchupdate BEFORE UPDATE OF full_text ON public.searches FOR EACH ROW WHEN ((old.full_text IS DISTINCT FROM new.full_text)) EXECUTE FUNCTION tsvector_update_trigger('words_typeahead', 'pg_catalog.simple', 'full_text');


--
-- Name: classification_aliases update_ca_paths_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_ca_paths_transitive_trigger AFTER UPDATE OF internal_name ON public.classification_aliases FOR EACH ROW WHEN (((old.internal_name)::text IS DISTINCT FROM (new.internal_name)::text)) EXECUTE FUNCTION public.generate_ca_paths_transitive_trigger_1();


--
-- Name: classification_tree_labels update_ca_paths_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_ca_paths_transitive_trigger AFTER UPDATE OF name ON public.classification_tree_labels FOR EACH ROW WHEN (((old.name)::text IS DISTINCT FROM (new.name)::text)) EXECUTE FUNCTION public.generate_ca_paths_transitive_trigger_3();


--
-- Name: classification_trees update_ca_paths_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_ca_paths_transitive_trigger AFTER UPDATE OF parent_classification_alias_id, classification_alias_id, classification_tree_label_id ON public.classification_trees FOR EACH ROW WHEN (((old.parent_classification_alias_id IS DISTINCT FROM new.parent_classification_alias_id) OR (old.classification_alias_id IS DISTINCT FROM new.classification_alias_id) OR (new.classification_tree_label_id IS DISTINCT FROM old.classification_tree_label_id))) EXECUTE FUNCTION public.generate_ca_paths_transitive_trigger_2();


--
-- Name: classification_contents update_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_ccc_relations_transitive_trigger AFTER UPDATE OF content_data_id, classification_id, relation ON public.classification_contents FOR EACH ROW WHEN (((old.content_data_id IS DISTINCT FROM new.content_data_id) OR (old.classification_id IS DISTINCT FROM new.classification_id) OR ((old.relation)::text IS DISTINCT FROM (new.relation)::text))) EXECUTE FUNCTION public.generate_ccc_relations_transitive_trigger_2();

ALTER TABLE public.classification_contents DISABLE TRIGGER update_ccc_relations_transitive_trigger;


--
-- Name: classification_groups update_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_ccc_relations_transitive_trigger AFTER UPDATE OF deleted_at ON public.classification_groups FOR EACH ROW WHEN (((old.deleted_at IS NULL) AND (new.deleted_at IS NOT NULL))) EXECUTE FUNCTION public.delete_ca_paths_transitive_trigger_1();

ALTER TABLE public.classification_groups DISABLE TRIGGER update_ccc_relations_transitive_trigger;


--
-- Name: classification_aliases update_classification_alias_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_classification_alias_paths_trigger AFTER UPDATE OF internal_name ON public.classification_aliases FOR EACH ROW WHEN (((old.internal_name)::text IS DISTINCT FROM (new.internal_name)::text)) EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_1();


--
-- Name: classification_tree_labels update_classification_alias_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_classification_alias_paths_trigger AFTER UPDATE OF name ON public.classification_tree_labels FOR EACH ROW WHEN (((old.name)::text IS DISTINCT FROM (new.name)::text)) EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_3();


--
-- Name: classification_trees update_classification_alias_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_classification_alias_paths_trigger AFTER UPDATE OF parent_classification_alias_id, classification_alias_id, classification_tree_label_id ON public.classification_trees FOR EACH ROW WHEN (((old.parent_classification_alias_id IS DISTINCT FROM new.parent_classification_alias_id) OR (old.classification_alias_id IS DISTINCT FROM new.classification_alias_id) OR (new.classification_tree_label_id IS DISTINCT FROM old.classification_tree_label_id))) EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_2();


--
-- Name: classification_contents update_collected_classification_content_relations_trigger_1; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_collected_classification_content_relations_trigger_1 AFTER UPDATE OF content_data_id, classification_id, relation ON public.classification_contents FOR EACH ROW WHEN (((old.content_data_id IS DISTINCT FROM new.content_data_id) OR (old.classification_id IS DISTINCT FROM new.classification_id) OR ((old.relation)::text IS DISTINCT FROM (new.relation)::text))) EXECUTE FUNCTION public.generate_collected_classification_content_relations_trigger_1();


--
-- Name: classification_groups update_collected_classification_content_relations_trigger_4; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_collected_classification_content_relations_trigger_4 AFTER UPDATE OF deleted_at ON public.classification_groups FOR EACH ROW WHEN ((old.deleted_at IS DISTINCT FROM new.deleted_at)) EXECUTE FUNCTION public.delete_collected_classification_content_relations_trigger_1();


--
-- Name: content_contents update_content_content_links_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_content_content_links_trigger AFTER UPDATE OF content_a_id, content_b_id, relation_b ON public.content_contents FOR EACH ROW WHEN (((old.content_a_id IS DISTINCT FROM new.content_a_id) OR (old.content_b_id IS DISTINCT FROM new.content_b_id) OR ((old.relation_b)::text IS DISTINCT FROM (new.relation_b)::text))) EXECUTE FUNCTION public.generate_content_content_links_trigger();


--
-- Name: users update_my_selection_watch_list; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_my_selection_watch_list AFTER UPDATE OF role_id ON public.users FOR EACH ROW WHEN ((old.role_id IS DISTINCT FROM new.role_id)) EXECUTE FUNCTION public.generate_my_selection_watch_list();


--
-- Name: schedules update_schedule_occurences_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_schedule_occurences_trigger AFTER UPDATE OF thing_id, duration, rrule, dtstart, relation, exdate, rdate ON public.schedules FOR EACH ROW WHEN (((old.thing_id IS DISTINCT FROM new.thing_id) OR (old.duration IS DISTINCT FROM new.duration) OR ((old.rrule)::text IS DISTINCT FROM (new.rrule)::text) OR (old.dtstart IS DISTINCT FROM new.dtstart) OR ((old.relation)::text IS DISTINCT FROM (new.relation)::text) OR (old.rdate IS DISTINCT FROM new.rdate) OR (old.exdate IS DISTINCT FROM new.exdate))) EXECUTE FUNCTION public.generate_schedule_occurences_trigger();


--
-- Name: things update_template_definitions_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_template_definitions_trigger AFTER UPDATE OF schema, boost, content_type ON public.things FOR EACH ROW WHEN (((new.template = true) AND ((old.schema IS DISTINCT FROM new.schema) OR (old.boost IS DISTINCT FROM new.boost) OR ((old.content_type)::text IS DISTINCT FROM (new.content_type)::text)))) EXECUTE FUNCTION public.update_template_definitions_trigger();


--
-- Name: timeseries fk_rails_53ff16144f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timeseries
    ADD CONSTRAINT fk_rails_53ff16144f FOREIGN KEY (thing_id) REFERENCES public.things(id) ON DELETE CASCADE;


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: schedule_occurrences schedule_occurrences_schedule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_occurrences
    ADD CONSTRAINT schedule_occurrences_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES public.schedules(id) ON DELETE CASCADE;


--
-- Name: schedule_occurrences schedule_occurrences_thing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_occurrences
    ADD CONSTRAINT schedule_occurrences_thing_id_fkey FOREIGN KEY (thing_id) REFERENCES public.things(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO public, postgis;

INSERT INTO "schema_migrations" (version) VALUES
('20170116165448'),
('20170118091809'),
('20170131141857'),
('20170131145138'),
('20170202142906'),
('20170209101956'),
('20170209115919'),
('20170213144933'),
('20170307094512'),
('20170406115252'),
('20170412124816'),
('20170418141539'),
('20170523115242'),
('20170524132123'),
('20170524144644'),
('20170612114242'),
('20170620143810'),
('20170621070615'),
('20170624083501'),
('20170714114037'),
('20170720130827'),
('20170806152208'),
('20170807100953'),
('20170807131053'),
('20170808071705'),
('20170816140348'),
('20170817090756'),
('20170817151049'),
('20170821072749'),
('20170828102436'),
('20170905152134'),
('20170906131340'),
('20170908143555'),
('20170912133931'),
('20170915000001'),
('20170915000002'),
('20170915000003'),
('20170915000004'),
('20170918093456'),
('20170919085841'),
('20170920071933'),
('20170921160600'),
('20170921161200'),
('20170929140328'),
('20171000124018'),
('20171001084323'),
('20171001123612'),
('20171002085329'),
('20171002132936'),
('20171003142621'),
('20171004072726'),
('20171004114524'),
('20171004120235'),
('20171004125221'),
('20171004132930'),
('20171009130405'),
('20171102091700'),
('20171115121939'),
('20171121084202'),
('20171123083228'),
('20171128091456'),
('20171204092716'),
('20171206163333'),
('20180103144809'),
('20180105085118'),
('20180109095257'),
('20180111111106'),
('20180117073708'),
('20180122153121'),
('20180124091123'),
('20180222091614'),
('20180328122539'),
('20180329064133'),
('20180330063016'),
('20180410220414'),
('20180417130441'),
('20180421162723'),
('20180425110943'),
('20180430064709'),
('20180503125925'),
('20180507073804'),
('20180509130533'),
('20180525083121'),
('20180525084148'),
('20180529105933'),
('20180703135948'),
('20180705133931'),
('20180809084405'),
('20180811125951'),
('20180812123536'),
('20180813133739'),
('20180814141924'),
('20180815132305'),
('20180820064823'),
('20180907080412'),
('20180914085848'),
('20180917085622'),
('20180917103214'),
('20180918085636'),
('20180918135618'),
('20180921083454'),
('20180927090624'),
('20180928084042'),
('20181001000001'),
('20181001085516'),
('20181009131613'),
('20181011125030'),
('20181019075437'),
('20181106113333'),
('20181116090243'),
('20181123113811'),
('20181126000001'),
('20181127142527'),
('20181130130052'),
('20181229111741'),
('20181231081526'),
('20190107074405'),
('20190108154224'),
('20190110092936'),
('20190110151543'),
('20190117135807'),
('20190118113621'),
('20190118145915'),
('20190129083607'),
('20190312141313'),
('20190314094528'),
('20190325122951'),
('20190423083517'),
('20190423103601'),
('20190520124223'),
('20190531093158'),
('20190612084614'),
('20190613092317'),
('20190703082641'),
('20190704114636'),
('20190712074413'),
('20190716081614'),
('20190716130050'),
('20190801120456'),
('20190805085313'),
('20190821101746'),
('20190920075014'),
('20190926131653'),
('20191113092141'),
('20191119110348'),
('20191129131046'),
('20191204141710'),
('20191205123950'),
('20191219123847'),
('20191219143016'),
('20200116143539'),
('20200117095949'),
('20200131103229'),
('20200205143630'),
('20200213132354'),
('20200217100339'),
('20200218132801'),
('20200218151417'),
('20200219111406'),
('20200221115053'),
('20200224143507'),
('20200226121349'),
('20200410064408'),
('20200420130554'),
('20200514064724'),
('20200525104244'),
('20200529140637'),
('20200602070145'),
('20200721111525'),
('20200724094112'),
('20200728062727'),
('20200812110341'),
('20200812111137'),
('20200824121824'),
('20200824140802'),
('20200826082051'),
('20200903102806'),
('20200922112719'),
('20200928122555'),
('20201014110327'),
('20201016100223'),
('20201022061044'),
('20201030111544'),
('20201103120727'),
('20201105145022'),
('20201201103630'),
('20201207151843'),
('20201208210141'),
('20210208130744'),
('20210215102758'),
('20210217125404'),
('20210305080429'),
('20210310141132'),
('20210410183240'),
('20210413105611'),
('20210416120714'),
('20210421180706'),
('20210422111740'),
('20210510120343'),
('20210518074537'),
('20210518133349'),
('20210520123323'),
('20210522171126'),
('20210527121641'),
('20210602112830'),
('20210608125638'),
('20210621063801'),
('20210625202737'),
('20210628202054'),
('20210629094413'),
('20210709121013'),
('20210731090959'),
('20210802095013'),
('20210804140504'),
('20210817101040'),
('20210908095952'),
('20211001085525'),
('20211005125306'),
('20211005134137'),
('20211007123156'),
('20211011123517'),
('20211014062654'),
('20211021062347'),
('20211021111915'),
('20211122075759'),
('20211123081845'),
('20211130111352'),
('20211214135559'),
('20211216110505'),
('20211217094832'),
('20220105142232'),
('20220111132413'),
('20220113113445'),
('20220218095025'),
('20220221123152'),
('20220304071341'),
('20220316115212'),
('20220317105304'),
('20220317131316'),
('20220322104259'),
('20220426105827'),
('20220505135021'),
('20220513075644'),
('20220516134326'),
('20220520065309'),
('20220524095157'),
('20220530063350'),
('20220602074421'),
('20220613074116'),
('20220614085121'),
('20220615085015'),
('20220615104611'),
('20220617113231'),
('20220715173507'),
('20220905101007'),
('20220914090315'),
('20220915081205'),
('20220919112419'),
('20220920083836'),
('20220922061116'),
('20221017094112'),
('20221028074348'),
('20221118075303'),
('20221202071928');


