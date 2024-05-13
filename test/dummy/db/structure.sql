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
-- Name: array_reverse(anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.array_reverse(anyarray) RETURNS anyarray
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ARRAY( SELECT $1 [i] FROM generate_subscripts($1, 1) AS s(i) ORDER BY i DESC ); $_$;


--
-- Name: compute_thing_schema_types(jsonb, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compute_thing_schema_types(schema_types jsonb, template_name character varying DEFAULT NULL::character varying) RETURNS character varying[]
    LANGUAGE plpgsql
    AS $$ DECLARE agg_schema_types varchar []; BEGIN WITH RECURSIVE schema_ancestors AS ( SELECT t.ancestors, t.idx FROM jsonb_array_elements(schema_types) WITH ordinality AS t(ancestors, idx) WHERE t.ancestors IS NOT NULL UNION ALL SELECT t.ancestors, schema_ancestors.idx + t.idx * 100 FROM schema_ancestors, jsonb_array_elements(schema_ancestors.ancestors) WITH ordinality AS t(ancestors, idx) WHERE jsonb_typeof(schema_ancestors.ancestors) = 'array' ), collected_schema_types AS ( SELECT (schema_ancestors.ancestors->>0)::varchar AS ancestors, max(schema_ancestors.idx) AS idx FROM schema_ancestors WHERE jsonb_typeof(schema_ancestors.ancestors) != 'array' GROUP BY schema_ancestors.ancestors ) SELECT array_agg( ancestors ORDER BY collected_schema_types.idx )::varchar [] INTO agg_schema_types FROM collected_schema_types; IF array_length(agg_schema_types, 1) > 0 THEN agg_schema_types := agg_schema_types || ('dcls:' || template_name)::varchar; END IF; RETURN agg_schema_types; END; $$;


--
-- Name: concept_links_create_transitive_paths_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.concept_links_create_transitive_paths_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(new_concept_links.child_id)) FROM new_concept_links; RETURN NULL; END; $$;


--
-- Name: concept_links_delete_transitive_paths_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.concept_links_delete_transitive_paths_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(old_concept_links.child_id)) FROM old_concept_links; RETURN NULL; END; $$;


--
-- Name: concept_links_update_transitive_paths_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.concept_links_update_transitive_paths_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concept_links.child_id)) FROM ( SELECT DISTINCT new_concept_links.child_id FROM old_concept_links JOIN new_concept_links ON old_concept_links.id = new_concept_links.id WHERE old_concept_links.child_id IS DISTINCT FROM new_concept_links.child_id OR old_concept_links.parent_id IS DISTINCT FROM new_concept_links.parent_id OR old_concept_links.link_type IS DISTINCT FROM new_concept_links.link_type ) "updated_concept_links"; RETURN NULL; END; $$;


--
-- Name: concept_schemes_update_transitive_paths_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.concept_schemes_update_transitive_paths_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concepts.id)) FROM ( SELECT DISTINCT concepts.id FROM old_concept_schemes JOIN new_concept_schemes ON old_concept_schemes.id = new_concept_schemes.id JOIN concepts ON concepts.concept_scheme_id = new_concept_schemes.id WHERE old_concept_schemes.name IS DISTINCT FROM new_concept_schemes.name ) "updated_concepts"; RETURN NULL; END; $$;


--
-- Name: concepts_create_transitive_paths_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.concepts_create_transitive_paths_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(new_concepts.id)) FROM new_concepts; RETURN NULL; END; $$;


--
-- Name: concepts_delete_transitive_paths_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.concepts_delete_transitive_paths_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(old_concepts.id)) FROM old_concepts; RETURN NULL; END; $$;


--
-- Name: concepts_update_transitive_paths_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.concepts_update_transitive_paths_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concepts.id)) FROM ( SELECT DISTINCT new_concepts.id FROM old_concepts JOIN new_concepts ON old_concepts.id = new_concepts.id WHERE old_concepts.internal_name IS DISTINCT FROM new_concepts.internal_name OR old_concepts.concept_scheme_id IS DISTINCT FROM new_concepts.concept_scheme_id ) "updated_concepts"; RETURN NULL; END; $$;


--
-- Name: delete_ccc_relations_transitive_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_ccc_relations_transitive_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (ARRAY [OLD.content_data_id]::UUID []); RETURN NULL; END; $$;


--
-- Name: delete_ccc_relations_transitive_trigger_2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_ccc_relations_transitive_trigger_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive ( array_agg( collected_classification_content_relations_alias.content_data_id ) ) FROM ( SELECT DISTINCT classification_contents.content_data_id FROM old_classification_alias_paths_transitive INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY ( old_classification_alias_paths_transitive.full_path_ids ) AND classification_groups.deleted_at IS NULL INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id ) "collected_classification_content_relations_alias"; RETURN NULL; END; $$;


--
-- Name: delete_collected_classification_content_relations_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_collected_classification_content_relations_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_classification_content_relations ( (SELECT ARRAY_AGG(DISTINCT things.id) FROM things JOIN classification_contents ON things.id = classification_contents.content_data_id JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL WHERE classification_groups.classification_id = OLD.classification_id), ARRAY[]::uuid[]); RETURN NEW; END; $$;


--
-- Name: delete_concept_links_groups_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concept_links_groups_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM concept_links WHERE concept_links.id IN ( SELECT ncg.id FROM old_classification_groups ocg INNER JOIN new_classification_groups ncg ON ocg.id = ncg.id WHERE ocg.deleted_at IS NULL AND ncg.deleted_at IS NOT NULL ); RETURN NULL; END; $$;


--
-- Name: delete_concept_links_groups_trigger_function2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concept_links_groups_trigger_function2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM concept_links WHERE concept_links.id IN ( SELECT ocg.id FROM old_classification_groups ocg ); RETURN NULL; END; $$;


--
-- Name: delete_concept_links_to_histories_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concept_links_to_histories_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE insert_query TEXT; BEGIN SELECT 'INSERT INTO concept_link_histories (' || string_agg(column_name, ', ') || ') SELECT ' || string_agg('ocl.' || column_name, ', ') || ' FROM old_concept_links ocl RETURNING id;' INTO insert_query FROM information_schema.columns WHERE table_name = 'concept_link_histories' AND column_name != 'deleted_at'; EXECUTE insert_query; RETURN NULL; END; $$;


--
-- Name: delete_concept_links_trees_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concept_links_trees_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM concept_links WHERE concept_links.id IN ( SELECT nct.id FROM old_classification_trees oct INNER JOIN new_classification_trees nct ON oct.id = nct.id WHERE oct.deleted_at IS NULL AND nct.deleted_at IS NOT NULL ); RETURN NULL; END; $$;


--
-- Name: delete_concept_links_trees_trigger_function2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concept_links_trees_trigger_function2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM concept_links WHERE concept_links.id IN ( SELECT oct.id FROM old_classification_trees oct ); RETURN NULL; END; $$;


--
-- Name: delete_concept_schemes_to_histories_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concept_schemes_to_histories_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE insert_query TEXT; BEGIN SELECT 'INSERT INTO concept_scheme_histories (' || string_agg(column_name, ', ') || ') SELECT ' || string_agg('ocs.' || column_name, ', ') || ' FROM old_concept_schemes ocs RETURNING id;' INTO insert_query FROM information_schema.columns WHERE table_name = 'concept_scheme_histories' AND column_name != 'deleted_at'; EXECUTE insert_query; RETURN NULL; END; $$;


--
-- Name: delete_concept_schemes_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concept_schemes_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM concept_schemes WHERE concept_schemes.id IN ( SELECT nctl.id FROM old_classification_tree_labels octl INNER JOIN new_classification_tree_labels nctl ON octl.id = nctl.id WHERE octl.deleted_at IS NULL AND nctl.deleted_at IS NOT NULL ); RETURN NULL; END; $$;


--
-- Name: delete_concepts_to_histories_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concepts_to_histories_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE insert_query TEXT; BEGIN SELECT 'INSERT INTO concept_histories (' || string_agg(column_name, ', ') || ') SELECT ' || string_agg('oc.' || column_name, ', ') || ' FROM old_concepts oc RETURNING id;' INTO insert_query FROM information_schema.columns WHERE table_name = 'concept_histories' AND column_name != 'deleted_at'; EXECUTE insert_query; RETURN NULL; END; $$;


--
-- Name: delete_concepts_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_concepts_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM concepts WHERE concepts.id IN ( SELECT nca.id FROM old_classification_aliases oca INNER JOIN new_classification_aliases nca ON oca.id = nca.id WHERE oca.deleted_at IS NULL AND nca.deleted_at IS NOT NULL ); RETURN NULL; END; $$;


--
-- Name: delete_external_hashes_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_external_hashes_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM external_hashes WHERE external_hashes.id IN ( SELECT eh.id FROM external_hashes eh WHERE EXISTS ( SELECT 1 FROM old_thing_translations INNER JOIN things ON things.id = old_thing_translations.thing_id WHERE things.external_source_id = eh.external_source_id AND things.external_key = eh.external_key AND old_thing_translations.locale = eh.locale ) FOR UPDATE ); RETURN NULL; END; $$;


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
-- Name: delete_things_external_source_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_things_external_source_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM external_hashes eh WHERE eh.external_source_id = OLD.external_source_id AND eh.external_key = OLD.external_key; RETURN NEW; END; $$;


--
-- Name: generate_ccc_relations_transitive_trigger_1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ccc_relations_transitive_trigger_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive ( array_agg( collected_classification_content_relations_alias.content_data_id ) ) FROM ( SELECT DISTINCT classification_contents.content_data_id FROM new_classification_alias_paths_transitive INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY ( new_classification_alias_paths_transitive.full_path_ids ) AND classification_groups.deleted_at IS NULL INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id ) "collected_classification_content_relations_alias"; RETURN NULL; END; $$;


--
-- Name: generate_ccc_relations_transitive_trigger_2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_ccc_relations_transitive_trigger_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (ARRAY [NEW.content_data_id]::UUID []); RETURN NULL; END; $$;


--
-- Name: generate_classification_alias_paths(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_classification_alias_paths(classification_alias_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM classification_alias_paths WHERE id = ANY(classification_alias_ids); WITH RECURSIVE paths( id, parent_id, ancestor_ids, full_path_ids, full_path_names, tree_label_id ) AS ( SELECT classification_aliases.id, classification_trees.parent_classification_alias_id, ARRAY []::uuid [], ARRAY [classification_aliases.id], ARRAY [classification_aliases.internal_name], classification_trees.classification_tree_label_id FROM classification_trees JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id WHERE classification_trees.classification_alias_id = ANY(classification_alias_ids) UNION ALL SELECT paths.id, classification_trees.parent_classification_alias_id, ancestor_ids || classification_aliases.id, full_path_ids || classification_aliases.id, full_path_names || classification_aliases.internal_name, classification_trees.classification_tree_label_id FROM classification_trees JOIN paths ON paths.parent_id = classification_trees.classification_alias_id JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id ) INSERT INTO classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names) SELECT paths.id, paths.ancestor_ids, paths.full_path_ids, paths.full_path_names || classification_tree_labels.name FROM paths JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id WHERE paths.parent_id IS NULL; RETURN; END; $$;


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
-- Name: generate_collected_cl_content_relations_transitive(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH direct_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_aliases.id ) classification_contents.content_data_id "thing_id", classification_aliases.id "classification_alias_id", classification_trees.classification_tree_label_id, TRUE "direct" FROM classification_contents JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL JOIN classification_aliases ON classification_aliases.id = classification_groups.classification_alias_id JOIN classification_trees ON classification_trees.classification_alias_id = classification_aliases.id AND classification_trees.deleted_at IS NULL WHERE classification_contents.content_data_id = ANY(thing_ids) ), full_classification_content_relations AS ( SELECT DISTINCT ON (classification_contents.content_data_id, a.e) classification_contents.content_data_id "thing_id", a.e "classification_alias_id", classification_trees.classification_tree_label_id, FALSE "direct" FROM classification_contents JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id JOIN classification_trees ON classification_trees.classification_alias_id = ANY ( classification_alias_paths_transitive.full_path_ids ) AND classification_trees.deleted_at IS NULL INNER JOIN LATERAL UNNEST( classification_alias_paths_transitive.full_path_ids ) AS a (e) ON a.e = classification_trees.classification_alias_id WHERE classification_contents.content_data_id = ANY(thing_ids) AND NOT EXISTS ( SELECT 1 FROM direct_classification_content_relations dccr WHERE dccr.thing_id = classification_contents.content_data_id AND dccr.classification_alias_id = a.e ) ), new_collected_classification_contents AS ( SELECT direct_classification_content_relations.thing_id, direct_classification_content_relations.classification_alias_id, direct_classification_content_relations.classification_tree_label_id, direct_classification_content_relations.direct FROM direct_classification_content_relations UNION SELECT full_classification_content_relations.thing_id, full_classification_content_relations.classification_alias_id, full_classification_content_relations.classification_tree_label_id, full_classification_content_relations.direct FROM full_classification_content_relations ), deleted_collected_classification_contents AS ( DELETE FROM collected_classification_contents WHERE collected_classification_contents.id IN ( SELECT ccc.id FROM collected_classification_contents ccc WHERE ccc.thing_id = ANY(thing_ids) AND NOT EXISTS ( SELECT 1 FROM new_collected_classification_contents WHERE new_collected_classification_contents.thing_id = ccc.thing_id AND new_collected_classification_contents.classification_alias_id = ccc.classification_alias_id ) ORDER BY ccc.id ASC FOR UPDATE SKIP LOCKED ) ) INSERT INTO collected_classification_contents ( thing_id, classification_alias_id, classification_tree_label_id, direct ) SELECT new_collected_classification_contents.thing_id, new_collected_classification_contents.classification_alias_id, new_collected_classification_contents.classification_tree_label_id, new_collected_classification_contents.direct FROM new_collected_classification_contents ON CONFLICT (thing_id, classification_alias_id) DO UPDATE SET classification_tree_label_id = EXCLUDED.classification_tree_label_id, direct = EXCLUDED.direct; END IF; END; $$;


--
-- Name: generate_collected_classification_content_relations(uuid[], uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_classification_content_relations(content_ids uuid[], excluded_classification_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM collected_classification_contents WHERE thing_id IN ( SELECT cccr.thing_id FROM collected_classification_contents cccr WHERE cccr.thing_id = ANY (content_ids) ORDER BY cccr.thing_id ASC FOR UPDATE SKIP LOCKED ); WITH direct_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_groups.classification_alias_id ) classification_contents.content_data_id "thing_id", classification_groups.classification_alias_id, classification_trees.classification_tree_label_id, TRUE "direct" FROM classification_contents JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id AND classification_trees.deleted_at IS NULL WHERE classification_contents.content_data_id = ANY (content_ids) AND classification_contents.classification_id <> ALL (excluded_classification_ids) ), full_classification_content_relations AS ( SELECT DISTINCT ON (classification_contents.content_data_id, a.e) classification_contents.content_data_id "thing_id", a.e "classification_alias_id", classification_trees.classification_tree_label_id "classification_tree_label_id", FALSE "direct" FROM classification_contents JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths.full_path_ids) AND classification_trees.deleted_at IS NULL CROSS JOIN LATERAL UNNEST(classification_alias_paths.full_path_ids) AS a (e) WHERE classification_contents.content_data_id = ANY (content_ids) AND classification_contents.classification_id <> ALL (excluded_classification_ids) AND NOT EXISTS ( SELECT 1 FROM direct_classification_content_relations dccr WHERE dccr.thing_id = classification_contents.content_data_id AND dccr.classification_alias_id = a.e ) ) INSERT INTO collected_classification_contents ( thing_id, classification_alias_id, classification_tree_label_id, direct ) SELECT direct_classification_content_relations.thing_id, direct_classification_content_relations.classification_alias_id, direct_classification_content_relations.classification_tree_label_id, direct_classification_content_relations.direct FROM direct_classification_content_relations UNION SELECT full_classification_content_relations.thing_id, full_classification_content_relations.classification_alias_id, full_classification_content_relations.classification_tree_label_id, full_classification_content_relations.direct FROM full_classification_content_relations ON CONFLICT DO NOTHING; RETURN; END; $$;


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
-- Name: generate_collected_classification_content_relations_trigger_5(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collected_classification_content_relations_trigger_5() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_classification_content_relations (ARRAY_AGG(content_data_id), ARRAY []::uuid []) FROM ( SELECT DISTINCT classification_contents.content_data_id FROM new_classification_alias_paths INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY ( new_classification_alias_paths.full_path_ids ) AND classification_groups.deleted_at IS NULL INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id ) "collected_classification_content_relations_alias"; RETURN NULL; END; $$;


--
-- Name: generate_collection_id_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collection_id_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.id := COALESCE(NEW.watch_list_id, NEW.stored_filter_id); RETURN NEW; END; $$;


--
-- Name: generate_collection_slug_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_collection_slug_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.slug := generate_unique_collection_slug (NEW.slug); RETURN NEW; END; $$;


--
-- Name: generate_content_content_links(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_content_content_links(content_content_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN INSERT INTO content_content_links ( content_a_id, content_b_id, content_content_id, relation ) SELECT content_contents.content_a_id AS "content_a_id", content_contents.content_b_id AS "content_b_id", content_contents.id AS "content_content_id", content_contents.relation_a AS "relation" FROM content_contents WHERE content_contents.id = ANY(content_content_ids) UNION SELECT content_contents.content_b_id AS "content_a_id", content_contents.content_a_id AS "content_b_id", content_contents.id AS "content_content_id", content_contents.relation_b AS "relation" FROM content_contents WHERE content_contents.id = ANY(content_content_ids) ON CONFLICT (content_content_id, content_a_id, content_b_id, relation) DO NOTHING; RETURN; END; $$;


--
-- Name: generate_content_content_links_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_content_content_links_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_content_content_links ( ARRAY_AGG(DISTINCT inserted_content_contents.id) ) FROM ( SELECT DISTINCT new_content_contents.id FROM new_content_contents ) "inserted_content_contents"; RETURN NULL; END; $$;


--
-- Name: generate_content_content_links_trigger2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_content_content_links_trigger2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_content_content_links ( ARRAY_AGG(DISTINCT updated_content_contents.id) ) FROM ( SELECT DISTINCT old_content_contents.id FROM old_content_contents INNER JOIN new_content_contents ON old_content_contents.id = new_content_contents.id WHERE old_content_contents.content_a_id IS DISTINCT FROM new_content_contents.content_a_id OR old_content_contents.relation_a IS DISTINCT FROM new_content_contents.relation_a OR old_content_contents.content_b_id IS DISTINCT FROM new_content_contents.content_b_id OR old_content_contents.relation_b IS DISTINCT FROM new_content_contents.relation_b ) "updated_content_contents"; RETURN NULL; END; $$;


--
-- Name: generate_my_selection_watch_list(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_my_selection_watch_list() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF EXISTS ( SELECT FROM roles WHERE roles.id = NEW.role_id AND roles.rank <> 0 ) THEN INSERT INTO collections ( name, TYPE, user_id, created_at, updated_at, full_path, full_path_names, my_selection ) SELECT 'Meine Auswahl', 'DataCycleCore::WatchList', users.id, NOW(), NOW(), 'Meine Auswahl', ARRAY []::varchar [], TRUE FROM users INNER JOIN roles ON roles.id = users.role_id WHERE users.id = NEW.id AND roles.rank <> 0 AND NOT EXISTS ( SELECT 1 FROM collections WHERE collections.my_selection AND collections.user_id = users.id ); ELSE DELETE FROM collections WHERE collections.user_id = NEW.id AND collections.my_selection; END IF; RETURN NEW; END; $$;


--
-- Name: generate_schedule_occurences(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_schedule_occurences(schedule_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN DELETE FROM schedule_occurrences WHERE schedule_id = ANY (schedule_ids); WITH occurences AS ( SELECT schedules.id, schedules.thing_id, CASE WHEN duration IS NULL THEN INTERVAL '1 seconds' WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds' ELSE duration END AS duration, unnest( get_occurrences ( schedules.rrule::rrule, schedules.dtstart AT TIME ZONE 'Europe/Vienna' ) ) AT TIME ZONE 'Europe/Vienna' AS occurence FROM schedules WHERE schedules.relation IS NOT NULL AND rrule LIKE '%UNTIL%' AND id = ANY (schedule_ids) UNION SELECT schedules.id, schedules.thing_id, CASE WHEN duration IS NULL THEN INTERVAL '1 seconds' WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds' ELSE duration END AS duration, unnest( get_occurrences ( (schedules.rrule || ';UNTIL=2037-12-31')::rrule, schedules.dtstart AT TIME ZONE 'Europe/Vienna' ) ) AT TIME ZONE 'Europe/Vienna' AS occurence FROM schedules WHERE schedules.relation IS NOT NULL AND rrule NOT LIKE '%UNTIL%' AND id = ANY (schedule_ids) UNION SELECT schedules.id, schedules.thing_id, CASE WHEN duration IS NULL THEN INTERVAL '1 seconds' WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds' ELSE duration END AS duration, schedules.dtstart AS occurence FROM schedules WHERE schedules.relation IS NOT NULL AND schedules.rrule IS NULL AND id = ANY (schedule_ids) UNION SELECT schedules.id, schedules.thing_id, CASE WHEN duration IS NULL THEN INTERVAL '1 seconds' WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds' ELSE duration END AS duration, unnest(schedules.rdate) AS occurence FROM schedules WHERE schedules.relation IS NOT NULL AND id = ANY (schedule_ids) ) INSERT INTO schedule_occurrences ( schedule_id, thing_id, duration, occurrence ) SELECT occurences.id, occurences.thing_id, occurences.duration, tstzrange( occurences.occurence, occurences.occurence + occurences.duration ) AS occurrence FROM occurences WHERE occurences.id = ANY (schedule_ids) AND NOT EXISTS ( SELECT 1 FROM ( SELECT id "schedule_id", UNNEST(exdate) "date" FROM schedules ) "exdates" WHERE exdates.schedule_id = occurences.id AND tstzrange( DATE_TRUNC('day', exdates.date), DATE_TRUNC('day', exdates.date) + INTERVAL '1 day' ) && tstzrange( occurences.occurence, occurences.occurence + occurences.duration ) ); RETURN; END; $$;


--
-- Name: generate_schedule_occurences_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_schedule_occurences_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_schedule_occurences(NEW.id || '{}'::UUID[]); RETURN NEW; END;$$;


--
-- Name: generate_thing_schema_types(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_thing_schema_types() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN SELECT compute_thing_schema_types(NEW."schema"->'schema_ancestors', NEW.template_name) INTO NEW.computed_schema_types; RETURN NEW; END; $$;


--
-- Name: generate_unique_collection_slug(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_unique_collection_slug(old_slug character varying, OUT new_slug character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$ BEGIN WITH input AS ( SELECT old_slug::VARCHAR AS slug, regexp_replace(old_slug, '-\d*$', '')::VARCHAR || '-' AS base_slug ) SELECT i.slug FROM input i LEFT JOIN collections a USING (slug) WHERE a.slug IS NULL UNION ALL ( SELECT i.base_slug || COALESCE( right(a.slug, length(i.base_slug) * -1)::int + 1, 1 ) FROM input i LEFT JOIN collections a ON a.slug LIKE (i.base_slug || '%') AND right(a.slug, length(i.base_slug) * -1) ~ '^\d+$' ORDER BY right(a.slug, length(i.base_slug) * -1)::int DESC ) LIMIT 1 INTO new_slug; END; $_$;


--
-- Name: geom_simple_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.geom_simple_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.geom_simple := ( st_simplify( ST_Force2D (COALESCE(NEW."geom", NEW."location", NEW.line)), 0.00001, TRUE ) ); RETURN NEW; END; $$;


--
-- Name: get_dict(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_dict(lang character varying) RETURNS regconfig
    LANGUAGE plpgsql
    AS $$ DECLARE dict varchar; BEGIN SELECT pg_dict_mappings.dict::regconfig INTO dict FROM pg_dict_mappings WHERE pg_dict_mappings.locale IN (lang, 'simple') LIMIT 1; IF dict IS NULL THEN dict := 'pg_catalog.simple'::regconfig; END IF; RETURN dict; END; $$;


--
-- Name: insert_classification_trees_order_a_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_classification_trees_order_a_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM reset_classification_aliases_order_a(ARRAY_AGG(classification_alias_id)) FROM ( SELECT new_classification_trees.classification_alias_id FROM new_classification_trees ) "reset_classification_trees_alias"; PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id)) FROM ( SELECT DISTINCT new_classification_trees.classification_tree_label_id FROM new_classification_trees ) "new_classification_trees_alias"; RETURN NULL; END; $$;


--
-- Name: insert_concept_links_trees_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_concept_links_trees_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN WITH updated_concepts AS ( UPDATE concepts SET concept_scheme_id = new_classification_trees.classification_tree_label_id FROM new_classification_trees WHERE new_classification_trees.classification_alias_id = concepts.id ) INSERT INTO concept_links(id, parent_id, child_id, link_type) SELECT new_classification_trees.id, new_classification_trees.parent_classification_alias_id, new_classification_trees.classification_alias_id, 'broader' FROM new_classification_trees ON CONFLICT DO NOTHING; RETURN NULL; END; $$;


--
-- Name: insert_concept_schemes_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_concept_schemes_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN INSERT INTO concept_schemes( id, name, external_system_id, external_key, internal, visibility, change_behaviour, created_at, updated_at ) SELECT nctl.id, nctl.name, nctl.external_source_id, nctl.external_key, nctl.internal, nctl.visibility, nctl.change_behaviour, nctl.created_at, nctl.updated_at FROM new_classification_tree_labels nctl ON CONFLICT DO NOTHING; RETURN NULL; END; $$;


--
-- Name: insert_concepts_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_concepts_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN INSERT INTO concepts( id, internal_name, name_i18n, description_i18n, external_system_id, external_key, order_a, assignable, internal, uri, ui_configs, created_at, updated_at ) SELECT ca.id, ca.internal_name, coalesce(ca.name_i18n, '{}'), coalesce(ca.description_i18n, '{}'), ca.external_source_id, ca.external_key, ca.order_a, ca.assignable, ca.internal, ca.uri, coalesce(ca.ui_configs, '{}'), NOW(), NOW() FROM new_classification_aliases ca ON CONFLICT DO NOTHING; RETURN NULL; END; $$;


--
-- Name: reset_classification_aliases_order_a(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reset_classification_aliases_order_a(classification_alias_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN IF array_length(classification_alias_ids, 1) > 0 THEN UPDATE classification_aliases SET order_a = NULL WHERE classification_aliases.order_a IS NOT NULL AND classification_aliases.id = ANY(classification_alias_ids); END IF; END; $$;


--
-- Name: to_classification_content_history(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_classification_content_history(content_id uuid, new_history_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$ DECLARE insert_query TEXT; BEGIN SELECT 'INSERT INTO classification_content_histories (content_data_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM classification_contents t WHERE t.content_data_id = ''' || content_id || '''::UUID;' INTO insert_query FROM information_schema.columns WHERE table_name = 'classification_content_histories' AND column_name NOT IN ('id', 'content_data_history_id'); EXECUTE insert_query; RETURN; END; $$;


--
-- Name: to_content_collection_link_history(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_content_collection_link_history(content_id uuid, new_history_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$ DECLARE insert_query TEXT; BEGIN SELECT 'INSERT INTO content_collection_link_histories (thing_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM content_collection_links t WHERE t.thing_id = ''' || content_id || '''::UUID;' INTO insert_query FROM information_schema.columns WHERE table_name = 'content_collection_link_histories' AND column_name NOT IN ('id', 'thing_history_id', 'stored_filter_id', 'watch_list_id'); EXECUTE insert_query; RETURN; END; $$;


--
-- Name: to_content_content_history(uuid, uuid, character varying, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_content_content_history(content_id uuid, new_history_id uuid, current_locale character varying, all_translations boolean DEFAULT false, deleted boolean DEFAULT false) RETURNS void
    LANGUAGE plpgsql
    AS $$ DECLARE insert_linked_query TEXT; insert_embedded_query TEXT; BEGIN SELECT 'INSERT INTO content_content_histories (content_a_history_id, content_b_history_id, content_b_history_type, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, t.content_b_id, ''DataCycleCore::Thing'', ' || string_agg('t.' || column_name, ', ') || ' FROM content_contents t INNER JOIN things ON things.id = t.content_b_id WHERE t.content_a_id = ''' || content_id || '''::UUID AND things.content_type != ''embedded'';' INTO insert_linked_query FROM information_schema.columns WHERE table_name = 'content_content_histories' AND column_name NOT IN ('id', 'content_a_history_id', 'content_b_history_id', 'content_b_history_type'); EXECUTE insert_linked_query; SELECT 'INSERT INTO content_content_histories (content_a_history_id, content_b_history_id, content_b_history_type, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, to_thing_history (t.content_b_id, ''' || current_locale || '''::VARCHAR, ' || all_translations || '::BOOLEAN, ' || deleted || '::BOOLEAN), ''DataCycleCore::Thing::History'', ' || string_agg('t.' || column_name, ', ') || ' FROM content_contents t INNER JOIN things ON things.id = t.content_b_id WHERE t.content_a_id = ''' || content_id || '''::UUID AND things.content_type = ''embedded'';' INTO insert_embedded_query FROM information_schema.columns WHERE table_name = 'content_content_histories' AND column_name NOT IN ('id', 'content_a_history_id', 'content_b_history_id', 'content_b_history_type'); EXECUTE insert_embedded_query; RETURN; END; $$;


--
-- Name: to_schedule_history(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_schedule_history(content_id uuid, new_history_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$ DECLARE insert_query TEXT; BEGIN SELECT 'INSERT INTO schedule_histories (thing_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM schedules t WHERE t.thing_id = ''' || content_id || '''::UUID;' INTO insert_query FROM information_schema.columns WHERE table_name = 'schedule_histories' AND column_name NOT IN ('id', 'thing_history_id'); EXECUTE insert_query; RETURN; END; $$;


--
-- Name: to_thing_history(uuid, character varying, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_thing_history(content_id uuid, current_locale character varying, all_translations boolean DEFAULT false, deleted boolean DEFAULT false) RETURNS uuid
    LANGUAGE plpgsql
    AS $$ DECLARE insert_query TEXT; new_history_id UUID; BEGIN SELECT 'INSERT INTO thing_histories (thing_id, deleted_at, ' || string_agg(column_name, ', ') || ') SELECT t.id, CASE WHEN t.deleted_at IS NOT NULL THEN t.deleted_at WHEN ' || deleted || '::BOOLEAN THEN transaction_timestamp() ELSE NULL END, ' || string_agg('t.' || column_name, ', ') || ' FROM things t WHERE t.id = ''' || content_id || '''::UUID LIMIT 1 RETURNING id;' INTO insert_query FROM information_schema.columns WHERE table_name = 'thing_histories' AND column_name NOT IN ('id', 'thing_id', 'deleted_at'); EXECUTE insert_query INTO new_history_id; PERFORM to_thing_history_translation ( content_id, new_history_id, current_locale, all_translations ); PERFORM to_classification_content_history (content_id, new_history_id); PERFORM to_content_content_history ( content_id, new_history_id, current_locale, all_translations, deleted ); PERFORM to_schedule_history (content_id, new_history_id); PERFORM to_content_collection_link_history (content_id, new_history_id); RETURN new_history_id; END; $$;


--
-- Name: to_thing_history_translation(uuid, uuid, character varying, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_thing_history_translation(content_id uuid, new_history_id uuid, current_locale character varying, all_translations boolean DEFAULT false) RETURNS void
    LANGUAGE plpgsql
    AS $$ DECLARE insert_query TEXT; BEGIN SELECT 'INSERT INTO thing_history_translations (thing_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM thing_translations t WHERE t.thing_id = ''' || content_id || '''::UUID AND (CASE WHEN ' || all_translations || '::BOOLEAN THEN t.locale IS NOT NULL ELSE t.locale = ''' || current_locale || '''::VARCHAR END);' INTO insert_query FROM information_schema.columns WHERE table_name = 'thing_history_translations' AND column_name NOT IN ('id', 'thing_history_id'); EXECUTE insert_query; RETURN; END; $$;


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
-- Name: update_classification_aliases_order_a(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_classification_aliases_order_a(tree_label_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN IF array_length(tree_label_ids, 1) > 0 THEN UPDATE classification_aliases SET order_a = w.order_a FROM ( WITH RECURSIVE paths (id, updated_at, full_order_a, tree_label_id) AS ( SELECT classification_aliases.id, classification_aliases.updated_at, ARRAY [ ( ROW_NUMBER() OVER ( PARTITION BY classification_trees.classification_tree_label_id ORDER BY classification_aliases.order_a ASC, classification_aliases.updated_at ASC ) ) ], classification_trees.classification_tree_label_id FROM classification_trees JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id AND classification_aliases.deleted_at IS NULL WHERE classification_trees.parent_classification_alias_id IS NULL AND classification_trees.deleted_at IS NULL AND classification_trees.classification_tree_label_id = ANY (tree_label_ids) UNION SELECT classification_trees.classification_alias_id, classification_aliases.updated_at, paths.full_order_a || ( ROW_NUMBER() OVER ( PARTITION BY classification_trees.classification_tree_label_id ORDER BY paths.full_order_a || classification_aliases.order_a::BIGINT ASC, classification_aliases.updated_at ASC ) ), classification_trees.classification_tree_label_id FROM classification_trees JOIN paths ON paths.id = classification_trees.parent_classification_alias_id JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id AND classification_aliases.deleted_at IS NULL WHERE classification_trees.deleted_at IS NULL ) SELECT paths.id, ( ROW_NUMBER() OVER ( PARTITION BY classification_tree_labels.id ORDER BY paths.full_order_a ASC, paths.updated_at ASC ) ) AS order_a FROM paths JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id ) w WHERE w.id = classification_aliases.id AND classification_aliases.order_a IS DISTINCT FROM w.order_a; END IF; END; $$;


--
-- Name: update_classification_aliases_order_a_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_classification_aliases_order_a_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id)) FROM ( SELECT DISTINCT classification_trees.classification_tree_label_id FROM classification_trees WHERE classification_trees.classification_alias_id IN ( SELECT updated_classification_aliases.id FROM updated_classification_aliases INNER JOIN old_classification_aliases ON old_classification_aliases.id = updated_classification_aliases.id WHERE old_classification_aliases.order_a IS DISTINCT FROM updated_classification_aliases.order_a AND updated_classification_aliases.order_a IS NOT NULL ) ) "updated_classification_aliases_alias"; RETURN NULL; END; $$;


--
-- Name: update_classification_tree_tree_label_id(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_classification_tree_tree_label_id(classification_tree_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN IF array_length(classification_tree_ids, 1) > 0 THEN UPDATE classification_trees SET classification_tree_label_id = updated_classification_trees.classification_tree_label_id FROM ( SELECT new_classification_trees.id, classification_trees.classification_tree_label_id FROM classification_trees INNER JOIN classification_alias_paths ON classification_alias_paths.ancestor_ids @> ARRAY [classification_trees.classification_alias_id]::UUID [] INNER JOIN classification_trees new_classification_trees ON classification_alias_paths.id = new_classification_trees.classification_alias_id WHERE classification_trees.deleted_at IS NULL AND classification_trees.id = ANY(classification_tree_ids) ) updated_classification_trees WHERE updated_classification_trees.id = classification_trees.id; END IF; END; $$;


--
-- Name: update_classification_tree_tree_label_id_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_classification_tree_tree_label_id_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM update_classification_tree_tree_label_id (ARRAY_AGG(id)) FROM ( SELECT new_classification_trees.id FROM new_classification_trees INNER JOIN old_classification_trees ON old_classification_trees.id = new_classification_trees.id WHERE new_classification_trees.deleted_at IS NULL AND new_classification_trees.classification_tree_label_id IS DISTINCT FROM old_classification_trees.classification_tree_label_id ) updated_classification_trees; RETURN NULL; END; $$;


--
-- Name: update_classification_trees_order_a_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_classification_trees_order_a_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM reset_classification_aliases_order_a(ARRAY_AGG(classification_alias_id)) FROM ( SELECT new_classification_trees.classification_alias_id FROM new_classification_trees INNER JOIN old_classification_trees ON old_classification_trees.id = new_classification_trees.id WHERE new_classification_trees.deleted_at IS NULL AND ( new_classification_trees.parent_classification_alias_id IS DISTINCT FROM old_classification_trees.parent_classification_alias_id OR new_classification_trees.classification_tree_label_id IS DISTINCT FROM old_classification_trees.classification_tree_label_id ) ) "reset_classification_trees_alias"; PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id)) FROM ( SELECT DISTINCT new_classification_trees.classification_tree_label_id FROM new_classification_trees INNER JOIN old_classification_trees ON old_classification_trees.id = new_classification_trees.id INNER JOIN classification_aliases ON classification_aliases.id = new_classification_trees.id AND classification_aliases.deleted_at IS NULL WHERE new_classification_trees.deleted_at IS NULL AND ( new_classification_trees.parent_classification_alias_id IS DISTINCT FROM old_classification_trees.parent_classification_alias_id OR new_classification_trees.classification_tree_label_id IS DISTINCT FROM old_classification_trees.classification_tree_label_id ) ) "updated_classification_trees_alias"; RETURN NULL; END; $$;


--
-- Name: update_collected_classification_content_relations_trigger_4(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_collected_classification_content_relations_trigger_4() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN PERFORM generate_collected_classification_content_relations ( ( SELECT ARRAY_AGG(DISTINCT things.id) FROM things JOIN classification_contents ON things.id = classification_contents.content_data_id JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id AND classification_groups.deleted_at IS NULL WHERE classification_groups.classification_id IN (NEW.classification_id, OLD.classification_id)), ARRAY []::uuid [] ); RETURN NEW; END; $$;


--
-- Name: update_concept_links_groups_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_concept_links_groups_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN UPDATE concept_links SET parent_id = ucg.classification_alias_id, child_id = ucg.mapped_ca_id FROM ( SELECT ncg.*, pcg.classification_alias_id AS mapped_ca_id FROM old_classification_groups ocg JOIN new_classification_groups ncg ON ocg.id = ncg.id JOIN primary_classification_groups pcg ON pcg.classification_id = ncg.classification_id AND pcg.deleted_at IS NULL WHERE ocg.classification_id IS DISTINCT FROM ncg.classification_id OR ocg.classification_alias_id IS DISTINCT FROM ncg.classification_alias_id ) "ucg" WHERE ucg.id = concept_links.id; RETURN NULL; END; $$;


--
-- Name: update_concept_links_trees_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_concept_links_trees_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN UPDATE concept_links SET parent_id = uct.parent_classification_alias_id, child_id = uct.classification_alias_id FROM ( SELECT nct.* FROM old_classification_trees oct JOIN new_classification_trees nct ON oct.id = nct.id WHERE oct.classification_alias_id IS DISTINCT FROM nct.classification_alias_id OR oct.parent_classification_alias_id IS DISTINCT FROM nct.parent_classification_alias_id ) "uct" WHERE uct.id = concept_links.id; RETURN NULL; END; $$;


--
-- Name: update_concept_schemes_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_concept_schemes_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN UPDATE concept_schemes SET name = uctl.name, external_system_id = uctl.external_source_id, external_key = uctl.external_key, internal = uctl.internal, visibility = uctl.visibility, change_behaviour = uctl.change_behaviour, updated_at = uctl.updated_at FROM ( SELECT nctl.* FROM old_classification_tree_labels octl INNER JOIN new_classification_tree_labels nctl ON octl.id = nctl.id WHERE octl.name IS DISTINCT FROM nctl.name OR octl.external_source_id IS DISTINCT FROM nctl.external_source_id OR octl.external_key IS DISTINCT FROM nctl.external_key OR octl.internal IS DISTINCT FROM nctl.internal OR octl.visibility IS DISTINCT FROM nctl.visibility OR octl.change_behaviour IS DISTINCT FROM nctl.change_behaviour OR octl.updated_at IS DISTINCT FROM nctl.updated_at ) "uctl" WHERE uctl.id = concept_schemes.id; RETURN NULL; END; $$;


--
-- Name: update_concepts_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_concepts_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN UPDATE concepts SET internal_name = uca.internal_name, name_i18n = coalesce(uca.name_i18n, '{}'), description_i18n = coalesce(uca.description_i18n, '{}'), external_system_id = uca.external_source_id, external_key = coalesce(uca.external_key, concepts.external_key), order_a = uca.order_a, assignable = uca.assignable, internal = uca.internal, uri = uca.uri, ui_configs = coalesce(uca.ui_configs, '{}'), updated_at = uca.updated_at FROM ( SELECT nca.* FROM old_classification_aliases oca INNER JOIN new_classification_aliases nca ON oca.id = nca.id WHERE oca.internal_name IS DISTINCT FROM nca.internal_name OR oca.name_i18n IS DISTINCT FROM nca.name_i18n OR oca.description_i18n IS DISTINCT FROM nca.description_i18n OR oca.external_source_id IS DISTINCT FROM nca.external_source_id OR oca.external_key IS DISTINCT FROM nca.external_key OR oca.order_a IS DISTINCT FROM nca.order_a OR oca.assignable IS DISTINCT FROM nca.assignable OR oca.internal IS DISTINCT FROM nca.internal OR oca.uri IS DISTINCT FROM nca.uri OR oca.ui_configs IS DISTINCT FROM nca.ui_configs OR oca.updated_at IS DISTINCT FROM nca.updated_at ) "uca" WHERE uca.id = concepts.id; RETURN NULL; END; $$;


--
-- Name: update_template_definitions_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_template_definitions_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN UPDATE things SET boost = updated_thing_templates.boost, content_type = updated_thing_templates.content_type, cache_valid_since = NOW() FROM ( SELECT DISTINCT ON (new_thing_templates.template_name) new_thing_templates.template_name, ("new_thing_templates"."schema"->'boost')::numeric AS boost, "new_thing_templates"."schema"->>'content_type' AS content_type FROM new_thing_templates INNER JOIN old_thing_templates ON old_thing_templates.template_name = new_thing_templates.template_name WHERE "new_thing_templates"."schema" IS DISTINCT FROM "old_thing_templates"."schema" ) "updated_thing_templates" WHERE things.template_name = updated_thing_templates.template_name; RETURN NULL; END; $$;


--
-- Name: upsert_ca_paths_transitive(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_ca_paths_transitive(concept_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths( id, parent_id, ancestor_ids, full_path_ids, full_path_names, link_types, tree_label_id ) AS ( SELECT c.id, cl.parent_id, ARRAY []::uuid [], ARRAY [c.id], ARRAY [c.internal_name], ARRAY [cl.link_type]::varchar [], c.concept_scheme_id FROM concepts c JOIN concept_links cl ON cl.child_id = c.id WHERE c.id = ANY(concept_ids) UNION ALL SELECT paths.id, cl.parent_id, ancestor_ids || c.id, full_path_ids || c.id, full_path_names || c.internal_name, CASE WHEN cl.parent_id IS NULL THEN paths.link_types ELSE paths.link_types || cl.link_type END, c.concept_scheme_id FROM concepts c JOIN paths ON paths.parent_id = c.id JOIN concept_links cl ON cl.child_id = c.id WHERE c.id <> ALL (paths.full_path_ids) ), child_paths( id, ancestor_ids, full_path_ids, full_path_names, link_types ) AS ( SELECT paths.id AS id, paths.ancestor_ids AS ancestor_ids, paths.full_path_ids AS full_path_ids, paths.full_path_names || cs.name AS full_path_names, paths.link_types AS link_types FROM paths JOIN concept_schemes cs ON cs.id = paths.tree_label_id WHERE paths.parent_id IS NULL UNION ALL SELECT c.id AS id, (cl.parent_id || p1.ancestor_ids) AS ancestors_ids, (c.id || p1.full_path_ids) AS full_path_ids, ( c.internal_name || p1.full_path_names ) AS full_path_names, (cl.link_type || p1.link_types) AS link_types FROM concepts c JOIN concept_links cl ON cl.child_id = c.id JOIN child_paths p1 ON p1.id = cl.parent_id WHERE c.id <> ALL (p1.full_path_ids) ), deleted_capt AS ( DELETE FROM classification_alias_paths_transitive WHERE classification_alias_paths_transitive.id IN ( SELECT capt.id FROM classification_alias_paths_transitive capt WHERE capt.full_path_ids && concept_ids AND NOT EXISTS ( SELECT 1 FROM child_paths WHERE child_paths.full_path_ids = capt.full_path_ids ) ORDER BY capt.id ASC FOR UPDATE SKIP LOCKED ) ) INSERT INTO classification_alias_paths_transitive ( classification_alias_id, ancestor_ids, full_path_ids, full_path_names, link_types ) SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id, child_paths.ancestor_ids, child_paths.full_path_ids, child_paths.full_path_names, array_remove(child_paths.link_types, NULL) FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO UPDATE SET full_path_names = EXCLUDED.full_path_names; END IF; END; $$;


--
-- Name: upsert_concept_tables_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_concept_tables_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN WITH groups AS ( SELECT cg.*, ( ( SELECT COUNT(cg1.id) <= 1 FROM classification_groups cg1 WHERE cg1.classification_alias_id = cg.classification_alias_id AND cg1.deleted_at IS NULL ) ) AS PRIMARY FROM new_classification_groups cg ), updated_concepts AS ( UPDATE concepts SET classification_id = groups.classification_id, external_system_id = coalesce( ca.external_source_id, c.external_source_id, concepts.external_system_id ), external_key = coalesce( ca.external_key, c.external_key, concepts.external_key ), uri = coalesce(ca.uri, c.uri, concepts.uri) FROM groups LEFT OUTER JOIN classifications c ON c.id = groups.classification_id AND c.deleted_at IS NULL LEFT OUTER JOIN classification_aliases ca ON ca.id = groups.classification_alias_id AND ca.deleted_at IS NULL WHERE concepts.id = groups.classification_alias_id AND groups.primary = TRUE ) INSERT INTO concept_links(id, parent_id, child_id, link_type) SELECT groups.id, groups.classification_alias_id, pcg.classification_alias_id, 'related' FROM groups JOIN primary_classification_groups pcg ON pcg.classification_id = groups.classification_id AND pcg.deleted_at IS NULL WHERE groups.primary = false ON CONFLICT DO NOTHING; RETURN NULL; END; $$;


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
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
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
         SELECT DISTINCT classification_groups.classification_id,
            first_value(classification_groups.classification_alias_id) OVER (PARTITION BY classification_groups.classification_id ORDER BY classification_groups.created_at) AS classification_alias_id
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
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    external_source_id uuid,
    internal boolean DEFAULT false NOT NULL,
    deleted_at timestamp without time zone,
    assignable boolean DEFAULT true NOT NULL,
    name_i18n jsonb DEFAULT '{}'::jsonb,
    description_i18n jsonb DEFAULT '{}'::jsonb,
    uri character varying,
    order_a integer,
    ui_configs jsonb,
    external_key character varying
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
    geog public.geography(MultiPolygon,4326),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    geom public.geometry(Geometry,4326)
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
    internal boolean DEFAULT false NOT NULL,
    deleted_at timestamp without time zone,
    visibility character varying[] DEFAULT '{}'::character varying[],
    change_behaviour character varying[] DEFAULT '{trigger_webhooks}'::character varying[],
    external_key character varying
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
-- Name: collected_classification_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collected_classification_contents (
    thing_id uuid NOT NULL,
    classification_alias_id uuid NOT NULL,
    classification_tree_label_id uuid NOT NULL,
    direct boolean DEFAULT false,
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL
);


--
-- Name: collection_concept_scheme_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_concept_scheme_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    collection_id uuid NOT NULL,
    concept_scheme_id uuid NOT NULL
);


--
-- Name: collection_shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_shares (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    collection_id uuid NOT NULL,
    shareable_id uuid NOT NULL,
    shareable_type character varying NOT NULL,
    user_id uuid GENERATED ALWAYS AS (
CASE
    WHEN ((shareable_type)::text = 'DataCycleCore::User'::text) THEN shareable_id
    ELSE NULL::uuid
END) STORED,
    user_group_id uuid GENERATED ALWAYS AS (
CASE
    WHEN ((shareable_type)::text = 'DataCycleCore::UserGroup'::text) THEN shareable_id
    ELSE NULL::uuid
END) STORED,
    role_id uuid GENERATED ALWAYS AS (
CASE
    WHEN ((shareable_type)::text = 'DataCycleCore::Role'::text) THEN shareable_id
    ELSE NULL::uuid
END) STORED
);


--
-- Name: collections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type character varying NOT NULL,
    name character varying,
    slug character varying,
    description text,
    description_stripped text,
    user_id uuid,
    full_path character varying,
    full_path_names character varying[],
    my_selection boolean DEFAULT false NOT NULL,
    manual_order boolean DEFAULT false NOT NULL,
    api boolean DEFAULT false NOT NULL,
    language character varying[],
    linked_stored_filter_id uuid,
    parameters jsonb,
    sort_parameters jsonb,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (((setweight(to_tsvector('simple'::regconfig, (COALESCE(name, ''::character varying))::text), 'A'::"char") || setweight(to_tsvector('simple'::regconfig, (COALESCE(slug, ''::character varying))::text), 'B'::"char")) || setweight(to_tsvector('simple'::regconfig, COALESCE(description_stripped, ''::text)), 'C'::"char"))) STORED
);


--
-- Name: concept_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    internal_name character varying,
    name_i18n jsonb DEFAULT '{}'::jsonb NOT NULL,
    description_i18n jsonb DEFAULT '{}'::jsonb NOT NULL,
    external_system_id uuid,
    external_key character varying,
    concept_scheme_id uuid,
    order_a integer,
    assignable boolean DEFAULT true NOT NULL,
    internal boolean DEFAULT false NOT NULL,
    uri character varying,
    ui_configs jsonb DEFAULT '{}'::jsonb NOT NULL,
    classification_id uuid,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    deleted_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: concept_link_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept_link_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_id uuid,
    child_id uuid NOT NULL,
    link_type character varying DEFAULT 'broader'::character varying NOT NULL,
    deleted_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: concept_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_id uuid,
    child_id uuid NOT NULL,
    link_type character varying DEFAULT 'broader'::character varying NOT NULL
);


--
-- Name: concept_scheme_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept_scheme_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    external_system_id uuid,
    internal boolean DEFAULT false NOT NULL,
    visibility character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    change_behaviour character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    deleted_at timestamp without time zone DEFAULT now() NOT NULL,
    external_key character varying
);


--
-- Name: concept_schemes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept_schemes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    external_system_id uuid,
    internal boolean DEFAULT false NOT NULL,
    visibility character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    change_behaviour character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    external_key character varying
);


--
-- Name: concepts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concepts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    internal_name character varying,
    name_i18n jsonb DEFAULT '{}'::jsonb NOT NULL,
    description_i18n jsonb DEFAULT '{}'::jsonb NOT NULL,
    external_system_id uuid,
    external_key character varying,
    concept_scheme_id uuid,
    order_a integer,
    assignable boolean DEFAULT true NOT NULL,
    internal boolean DEFAULT false NOT NULL,
    uri character varying,
    ui_configs jsonb DEFAULT '{}'::jsonb NOT NULL,
    classification_id uuid,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: content_collection_link_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_collection_link_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_history_id uuid,
    collection_id uuid,
    relation character varying,
    order_a integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: content_collection_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_collection_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_id uuid,
    collection_id uuid,
    relation character varying,
    order_a integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: thing_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_templates (
    template_name character varying NOT NULL,
    schema jsonb,
    computed_schema_types character varying[],
    content_type character varying GENERATED ALWAYS AS ((schema ->> 'content_type'::text)) STORED,
    boost numeric GENERATED ALWAYS AS (((schema -> 'boost'::text))::numeric) STORED,
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL
);


--
-- Name: content_properties; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_properties AS
 SELECT thing_templates.template_name,
    properties.key AS property_name,
    properties.value AS property_definition
   FROM (public.thing_templates
     CROSS JOIN LATERAL jsonb_each((thing_templates.schema -> 'properties'::text)) properties(key, value));


--
-- Name: content_computed_properties; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_computed_properties AS
 SELECT content_properties.template_name,
    content_properties.property_name,
    split_part(parameters.value, '.'::text, 1) AS compute_parameter_property_name
   FROM public.content_properties,
    LATERAL jsonb_array_elements_text(((content_properties.property_definition -> 'compute'::text) -> 'parameters'::text)) parameters(value)
  WHERE (jsonb_typeof(((content_properties.property_definition -> 'compute'::text) -> 'parameters'::text)) = 'array'::text);


--
-- Name: content_content_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_content_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_a_history_id uuid,
    relation_a character varying,
    content_b_history_id uuid,
    content_b_history_type character varying,
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
    content_b_id uuid,
    content_content_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    relation character varying
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
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    order_a integer
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
-- Name: things; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.things (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    metadata jsonb,
    template_name character varying NOT NULL,
    external_source_id uuid,
    external_key character varying,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    cache_valid_since timestamp without time zone,
    created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
    deleted_at timestamp without time zone,
    location public.geometry(Point,4326),
    is_part_of uuid,
    validity_range tstzrange,
    boost numeric,
    content_type character varying,
    representation_of_id uuid,
    version_name character varying,
    line public.geometry(MultiLineStringZ,4326),
    last_updated_locale character varying,
    write_history boolean DEFAULT false NOT NULL,
    geom_simple public.geometry(Geometry,4326),
    geom public.geometry(GeometryZ,4326)
);


--
-- Name: content_meta_items; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_meta_items AS
 SELECT things.id,
    'DataCycleCore::Thing'::text AS content_type,
    things.template_name,
    thing_templates.schema,
    things.external_source_id,
    things.external_key,
    things.created_by,
    things.updated_by,
    things.deleted_by
   FROM (public.things
     JOIN public.thing_templates ON (((thing_templates.template_name)::text = (things.template_name)::text)));


--
-- Name: content_property_dependencies; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.content_property_dependencies AS
 SELECT t2.id AS content_id,
    t2.template_name,
    content_computed_properties.property_name,
    content_computed_properties.compute_parameter_property_name,
    things.id AS dependent_content_id,
    things.template_name AS dependent_content_template_name
   FROM (((public.things
     JOIN public.content_contents ON ((content_contents.content_b_id = things.id)))
     JOIN public.things t2 ON ((t2.id = content_contents.content_a_id)))
     JOIN public.content_computed_properties ON ((((content_computed_properties.template_name)::text = (t2.template_name)::text) AND (content_computed_properties.compute_parameter_property_name = (content_contents.relation_a)::text))))
UNION
 SELECT t2.id AS content_id,
    t2.template_name,
    content_computed_properties.property_name,
    content_computed_properties.compute_parameter_property_name,
    things.id AS dependent_content_id,
    things.template_name AS dependent_content_template_name
   FROM (((public.things
     JOIN public.content_contents ON (((content_contents.content_a_id = things.id) AND (content_contents.relation_b IS NOT NULL))))
     JOIN public.things t2 ON ((t2.id = content_contents.content_b_id)))
     JOIN public.content_computed_properties ON ((((content_computed_properties.template_name)::text = (t2.template_name)::text) AND (content_computed_properties.compute_parameter_property_name = (content_contents.relation_b)::text))));


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
-- Name: delayed_jobs_statistics; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.delayed_jobs_statistics AS
 SELECT delayed_jobs.queue AS queue_name,
    sum(1) FILTER (WHERE (delayed_jobs.failed_at IS NOT NULL)) AS failed,
    sum(1) FILTER (WHERE ((delayed_jobs.failed_at IS NULL) AND (delayed_jobs.locked_at IS NOT NULL) AND (delayed_jobs.locked_by IS NOT NULL))) AS running,
    sum(1) FILTER (WHERE ((delayed_jobs.failed_at IS NULL) AND (delayed_jobs.locked_at IS NULL) AND (delayed_jobs.locked_by IS NULL))) AS queued,
    array_agg(DISTINCT delayed_jobs.delayed_reference_type) FILTER (WHERE (delayed_jobs.failed_at IS NOT NULL)) AS failed_types,
    array_agg(DISTINCT delayed_jobs.delayed_reference_type) FILTER (WHERE ((delayed_jobs.failed_at IS NULL) AND (delayed_jobs.locked_at IS NOT NULL) AND (delayed_jobs.locked_by IS NOT NULL))) AS running_types,
    array_agg(DISTINCT delayed_jobs.delayed_reference_type) FILTER (WHERE ((delayed_jobs.failed_at IS NULL) AND (delayed_jobs.locked_at IS NULL) AND (delayed_jobs.locked_by IS NULL))) AS queued_types
   FROM public.delayed_jobs
  GROUP BY delayed_jobs.queue;


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
    thing_duplicates.method AS duplicate_method,
    thing_duplicates.id AS thing_duplicate_id,
    thing_duplicates.false_positive
   FROM public.thing_duplicates
UNION ALL
 SELECT thing_duplicates.thing_id AS duplicate_id,
    thing_duplicates.thing_duplicate_id AS original_id,
    thing_duplicates.score,
    thing_duplicates.method AS duplicate_method,
    thing_duplicates.id AS thing_duplicate_id,
    thing_duplicates.false_positive
   FROM public.thing_duplicates;


--
-- Name: external_hashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_hashes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_source_id uuid NOT NULL,
    external_key character varying NOT NULL,
    hash_value character varying,
    locale character varying NOT NULL,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


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
    deactivated boolean DEFAULT false NOT NULL,
    last_successful_download_time interval,
    last_download_time interval,
    last_successful_import_time interval,
    last_import_time interval
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
    words_typeahead tsvector,
    self_contained boolean DEFAULT true NOT NULL
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
    external_source_id uuid,
    external_key character varying,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    cache_valid_since timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    location public.geometry(Point,4326),
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
    ui_locale character varying DEFAULT 'de'::character varying NOT NULL,
    deleted_at timestamp without time zone
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
-- Name: classification_alias_paths_transitive classification_alias_paths_transitive_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_alias_paths_transitive
    ADD CONSTRAINT classification_alias_paths_transitive_unique UNIQUE (full_path_ids);


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
-- Name: collected_classification_contents collected_classification_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_classification_contents
    ADD CONSTRAINT collected_classification_contents_pkey PRIMARY KEY (id);


--
-- Name: collection_concept_scheme_links collection_concept_scheme_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_concept_scheme_links
    ADD CONSTRAINT collection_concept_scheme_links_pkey PRIMARY KEY (id);


--
-- Name: collection_shares collection_shares_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_shares
    ADD CONSTRAINT collection_shares_pkey PRIMARY KEY (id);


--
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);


--
-- Name: concept_histories concept_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_histories
    ADD CONSTRAINT concept_histories_pkey PRIMARY KEY (id);


--
-- Name: concept_link_histories concept_link_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_link_histories
    ADD CONSTRAINT concept_link_histories_pkey PRIMARY KEY (id);


--
-- Name: concept_links concept_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_links
    ADD CONSTRAINT concept_links_pkey PRIMARY KEY (id);


--
-- Name: concept_scheme_histories concept_scheme_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_scheme_histories
    ADD CONSTRAINT concept_scheme_histories_pkey PRIMARY KEY (id);


--
-- Name: concept_schemes concept_schemes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_schemes
    ADD CONSTRAINT concept_schemes_pkey PRIMARY KEY (id);


--
-- Name: concepts concepts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concepts
    ADD CONSTRAINT concepts_pkey PRIMARY KEY (id);


--
-- Name: content_collection_link_histories content_collection_link_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_collection_link_histories
    ADD CONSTRAINT content_collection_link_histories_pkey PRIMARY KEY (id);


--
-- Name: content_collection_links content_collection_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_collection_links
    ADD CONSTRAINT content_collection_links_pkey PRIMARY KEY (id);


--
-- Name: content_content_histories content_content_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_content_histories
    ADD CONSTRAINT content_content_histories_pkey PRIMARY KEY (id);


--
-- Name: content_content_links content_content_links_uq_constraint; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_content_links
    ADD CONSTRAINT content_content_links_uq_constraint UNIQUE (content_content_id, content_a_id, content_b_id, relation);


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
-- Name: external_hashes external_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_hashes
    ADD CONSTRAINT external_hashes_pkey PRIMARY KEY (id);


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
-- Name: thing_templates thing_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_templates
    ADD CONSTRAINT thing_templates_pkey PRIMARY KEY (template_name);


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
-- Name: by_thing_id_version_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_thing_id_version_name ON public.thing_histories USING btree (thing_id, version_name);


--
-- Name: by_watch_list_hashable; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_watch_list_hashable ON public.watch_list_data_hashes USING btree (watch_list_id, hashable_id, hashable_type);


--
-- Name: capt_classification_alias_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capt_classification_alias_id_idx ON public.classification_alias_paths_transitive USING btree (classification_alias_id);


--
-- Name: ccc_ca_id_t_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ccc_ca_id_t_id_idx ON public.collected_classification_contents USING btree (classification_alias_id, thing_id, direct);


--
-- Name: ccc_ctl_id_t_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ccc_ctl_id_t_id_idx ON public.collected_classification_contents USING btree (classification_tree_label_id, thing_id, direct);


--
-- Name: ccc_unique_thing_id_classification_alias_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ccc_unique_thing_id_classification_alias_id_idx ON public.collected_classification_contents USING btree (thing_id, classification_alias_id);


--
-- Name: ccl_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ccl_unique_index ON public.content_collection_links USING btree (thing_id, relation, collection_id);


--
-- Name: ccsl_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ccsl_unique_index ON public.collection_concept_scheme_links USING btree (collection_id, concept_scheme_id);


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
-- Name: classification_aliases_order_a_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_aliases_order_a_idx ON public.classification_aliases USING btree (order_a);


--
-- Name: classification_content_data_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_content_data_history_id_idx ON public.classification_content_histories USING btree (content_data_history_id);


--
-- Name: classification_groups_ca_id_c_id_uq_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX classification_groups_ca_id_c_id_uq_idx ON public.classification_groups USING btree (classification_alias_id, classification_id) WHERE (deleted_at IS NULL);


--
-- Name: classification_polygons_classification_alias_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_polygons_classification_alias_id_id_idx ON public.classification_polygons USING btree (classification_alias_id, id);


--
-- Name: classification_polygons_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_polygons_geom_idx ON public.classification_polygons USING gist (geom);


--
-- Name: classification_string_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_string_idx ON public.searches USING gin (classification_string public.gin_trgm_ops);


--
-- Name: collection_shares_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX collection_shares_unique_index ON public.collection_shares USING btree (collection_id, shareable_id, shareable_type);


--
-- Name: collections_search_vector_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX collections_search_vector_idx ON public.collections USING gin (search_vector);


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
-- Name: index_classification_aliases_unique_external_source_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_aliases_unique_external_source_id_and_key ON public.classification_aliases USING btree (external_source_id, external_key) WHERE (deleted_at IS NULL);


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
-- Name: index_classification_trees_unique_classification_alias; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_trees_unique_classification_alias ON public.classification_trees USING btree (classification_alias_id) WHERE (deleted_at IS NULL);


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
-- Name: index_classifications_unique_external_source_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classifications_unique_external_source_id_and_key ON public.classifications USING btree (external_source_id, external_key) WHERE (deleted_at IS NULL);


--
-- Name: index_collection_shares_on_shareable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collection_shares_on_shareable_type ON public.collection_shares USING btree (shareable_type);


--
-- Name: index_collections_on_full_path; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collections_on_full_path ON public.collections USING gin (full_path public.gin_trgm_ops);


--
-- Name: index_collections_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collections_on_name ON public.collections USING gin (name public.gin_trgm_ops);


--
-- Name: index_collections_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_collections_on_slug ON public.collections USING btree (slug) WHERE (slug IS NOT NULL);


--
-- Name: index_collections_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collections_on_updated_at ON public.collections USING btree (updated_at);


--
-- Name: index_collections_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collections_on_user_id ON public.collections USING btree (user_id);


--
-- Name: index_concept_histories_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_histories_on_classification_id ON public.concept_histories USING btree (classification_id);


--
-- Name: index_concept_histories_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_histories_on_deleted_at ON public.concept_histories USING btree (deleted_at);


--
-- Name: index_concept_histories_on_external_system_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_concept_histories_on_external_system_id_and_external_key ON public.concept_histories USING btree (external_system_id, external_key) WHERE ((external_system_id IS NOT NULL) AND (external_key IS NOT NULL));


--
-- Name: index_concept_histories_on_internal_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_histories_on_internal_name ON public.concept_histories USING gin (internal_name public.gin_trgm_ops);


--
-- Name: index_concept_histories_on_order_a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_histories_on_order_a ON public.concept_histories USING btree (order_a);


--
-- Name: index_concept_link_histories_on_child_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_concept_link_histories_on_child_id ON public.concept_link_histories USING btree (child_id) WHERE ((link_type)::text = 'broader'::text);


--
-- Name: index_concept_link_histories_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_link_histories_on_deleted_at ON public.concept_link_histories USING btree (deleted_at);


--
-- Name: index_concept_link_histories_on_link_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_link_histories_on_link_type ON public.concept_link_histories USING btree (link_type);


--
-- Name: index_concept_link_histories_on_parent_id_and_child_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_concept_link_histories_on_parent_id_and_child_id ON public.concept_link_histories USING btree (parent_id, child_id);


--
-- Name: index_concept_links_on_child_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_concept_links_on_child_id ON public.concept_links USING btree (child_id) WHERE ((link_type)::text = 'broader'::text);


--
-- Name: index_concept_links_on_link_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_links_on_link_type ON public.concept_links USING btree (link_type);


--
-- Name: index_concept_links_on_parent_id_and_child_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_concept_links_on_parent_id_and_child_id ON public.concept_links USING btree (parent_id, child_id);


--
-- Name: index_concept_scheme_histories_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_scheme_histories_on_deleted_at ON public.concept_scheme_histories USING btree (deleted_at);


--
-- Name: index_concept_scheme_histories_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_scheme_histories_on_name ON public.concept_scheme_histories USING btree (name);


--
-- Name: index_concept_schemes_on_external_system_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_concept_schemes_on_external_system_id_and_external_key ON public.concept_schemes USING btree (external_system_id, external_key);


--
-- Name: index_concept_schemes_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concept_schemes_on_name ON public.concept_schemes USING btree (name);


--
-- Name: index_concepts_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concepts_on_classification_id ON public.concepts USING btree (classification_id);


--
-- Name: index_concepts_on_external_system_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_concepts_on_external_system_id_and_external_key ON public.concepts USING btree (external_system_id, external_key) WHERE ((external_system_id IS NOT NULL) AND (external_key IS NOT NULL));


--
-- Name: index_concepts_on_full_order_concept_scheme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concepts_on_full_order_concept_scheme_id ON public.concepts USING btree (order_a, id, concept_scheme_id);


--
-- Name: index_concepts_on_internal_name_btree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concepts_on_internal_name_btree ON public.concepts USING btree (internal_name);


--
-- Name: index_concepts_on_internal_name_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concepts_on_internal_name_gin ON public.concepts USING gin (internal_name public.gin_trgm_ops);


--
-- Name: index_concepts_on_order_a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_concepts_on_order_a ON public.concepts USING btree (order_a);


--
-- Name: index_content_collection_link_histories_on_order_a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_collection_link_histories_on_order_a ON public.content_collection_link_histories USING btree (order_a);


--
-- Name: index_content_collection_link_histories_on_relation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_collection_link_histories_on_relation ON public.content_collection_link_histories USING btree (relation);


--
-- Name: index_content_collection_link_histories_on_thing_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_collection_link_histories_on_thing_history_id ON public.content_collection_link_histories USING btree (thing_history_id);


--
-- Name: index_content_collection_links_on_order_a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_collection_links_on_order_a ON public.content_collection_links USING btree (order_a);


--
-- Name: index_content_collection_links_on_relation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_collection_links_on_relation ON public.content_collection_links USING btree (relation);


--
-- Name: index_content_collection_links_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_collection_links_on_thing_id ON public.content_collection_links USING btree (thing_id);


--
-- Name: index_content_content_histories_on_content_a_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_content_histories_on_content_a_history_id ON public.content_content_histories USING btree (content_a_history_id);


--
-- Name: index_content_content_links_on_content_b_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_content_links_on_content_b_id ON public.content_content_links USING btree (content_b_id);


--
-- Name: index_content_content_links_on_contents_a_b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_content_links_on_contents_a_b ON public.content_content_links USING btree (content_a_id, content_b_id);


--
-- Name: index_content_contents_on_content_b_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_contents_on_content_b_id ON public.content_contents USING btree (content_b_id);


--
-- Name: index_ctl_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ctl_on_external_source_id_and_external_key ON public.classification_tree_labels USING btree (external_source_id, external_key) WHERE (deleted_at IS NULL);


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
-- Name: index_external_hash_on_external_source_id_external_key_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_hash_on_external_source_id_external_key_locale ON public.external_hashes USING btree (external_source_id, external_key, locale);


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
-- Name: index_schedules_on_thing_id_id_relation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedules_on_thing_id_id_relation ON public.schedules USING btree (thing_id, id, relation);


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
-- Name: index_thing_templates_on_boost; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_templates_on_boost ON public.thing_templates USING btree (boost);


--
-- Name: index_thing_templates_on_computed_schema_types; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_templates_on_computed_schema_types ON public.thing_templates USING gin (computed_schema_types);


--
-- Name: index_thing_templates_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_templates_on_content_type ON public.thing_templates USING btree (content_type);


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
-- Name: index_things_on_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_external_key ON public.things USING btree (external_key);


--
-- Name: index_things_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_things_on_external_source_id_and_external_key ON public.things USING btree (external_source_id, external_key);


--
-- Name: index_things_on_geom_simple_spatial; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_geom_simple_spatial ON public.things USING gist (geom_simple);


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
-- Name: index_things_on_template_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_template_name ON public.things USING btree (template_name);


--
-- Name: index_things_on_updated_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_updated_by ON public.things USING btree (updated_by);


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

CREATE INDEX thing_translations_name_idx ON public.thing_translations USING btree (((content ->> 'name'::text)));


--
-- Name: things_geom_simple_geography_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX things_geom_simple_geography_idx ON public.things USING gist (public.geography(geom_simple));


--
-- Name: things_id_content_type_validity_range_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX things_id_content_type_validity_range_template_name_idx ON public.things USING btree (id, content_type, validity_range, template_name);


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
-- Name: wldh_order_a_brin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX wldh_order_a_brin_idx ON public.watch_list_data_hashes USING brin (order_a, created_at);


--
-- Name: words_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_idx ON public.searches USING gin (full_text public.gin_trgm_ops);


--
-- Name: concept_links concept_links_create_transitive_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concept_links_create_transitive_paths_trigger AFTER INSERT ON public.concept_links REFERENCING NEW TABLE AS new_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.concept_links_create_transitive_paths_trigger_function();

ALTER TABLE public.concept_links DISABLE TRIGGER concept_links_create_transitive_paths_trigger;


--
-- Name: concept_links concept_links_delete_transitive_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concept_links_delete_transitive_paths_trigger AFTER DELETE ON public.concept_links REFERENCING OLD TABLE AS old_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.concept_links_delete_transitive_paths_trigger_function();

ALTER TABLE public.concept_links DISABLE TRIGGER concept_links_delete_transitive_paths_trigger;


--
-- Name: concept_links concept_links_update_transitive_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concept_links_update_transitive_paths_trigger AFTER UPDATE ON public.concept_links REFERENCING OLD TABLE AS old_concept_links NEW TABLE AS new_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.concept_links_update_transitive_paths_trigger_function();

ALTER TABLE public.concept_links DISABLE TRIGGER concept_links_update_transitive_paths_trigger;


--
-- Name: concept_schemes concept_schemes_update_transitive_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concept_schemes_update_transitive_paths_trigger AFTER UPDATE ON public.concept_schemes REFERENCING OLD TABLE AS old_concept_schemes NEW TABLE AS new_concept_schemes FOR EACH STATEMENT EXECUTE FUNCTION public.concept_schemes_update_transitive_paths_trigger_function();

ALTER TABLE public.concept_schemes DISABLE TRIGGER concept_schemes_update_transitive_paths_trigger;


--
-- Name: concepts concepts_create_transitive_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concepts_create_transitive_paths_trigger AFTER INSERT ON public.concepts REFERENCING NEW TABLE AS new_concepts FOR EACH STATEMENT EXECUTE FUNCTION public.concepts_create_transitive_paths_trigger_function();

ALTER TABLE public.concepts DISABLE TRIGGER concepts_create_transitive_paths_trigger;


--
-- Name: concepts concepts_delete_transitive_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concepts_delete_transitive_paths_trigger AFTER DELETE ON public.concepts REFERENCING OLD TABLE AS old_concepts FOR EACH STATEMENT EXECUTE FUNCTION public.concepts_delete_transitive_paths_trigger_function();

ALTER TABLE public.concepts DISABLE TRIGGER concepts_delete_transitive_paths_trigger;


--
-- Name: concepts concepts_update_transitive_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concepts_update_transitive_paths_trigger AFTER UPDATE ON public.concepts REFERENCING OLD TABLE AS old_concepts NEW TABLE AS new_concepts FOR EACH STATEMENT EXECUTE FUNCTION public.concepts_update_transitive_paths_trigger_function();

ALTER TABLE public.concepts DISABLE TRIGGER concepts_update_transitive_paths_trigger;


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
-- Name: classification_groups delete_collected_classification_content_relations_trigger_1; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_collected_classification_content_relations_trigger_1 AFTER DELETE ON public.classification_groups FOR EACH ROW EXECUTE FUNCTION public.delete_collected_classification_content_relations_trigger_1();


--
-- Name: classification_groups delete_concept_links_groups_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concept_links_groups_trigger AFTER UPDATE ON public.classification_groups REFERENCING OLD TABLE AS old_classification_groups NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concept_links_groups_trigger_function();


--
-- Name: classification_groups delete_concept_links_groups_trigger2; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concept_links_groups_trigger2 AFTER DELETE ON public.classification_groups REFERENCING OLD TABLE AS old_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concept_links_groups_trigger_function2();


--
-- Name: concept_links delete_concept_links_to_histories_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concept_links_to_histories_trigger AFTER DELETE ON public.concept_links REFERENCING OLD TABLE AS old_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concept_links_to_histories_trigger_function();


--
-- Name: classification_trees delete_concept_links_trees_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concept_links_trees_trigger AFTER UPDATE ON public.classification_trees REFERENCING OLD TABLE AS old_classification_trees NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concept_links_trees_trigger_function();


--
-- Name: classification_trees delete_concept_links_trees_trigger2; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concept_links_trees_trigger2 AFTER DELETE ON public.classification_trees REFERENCING OLD TABLE AS old_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concept_links_trees_trigger_function2();


--
-- Name: concept_schemes delete_concept_schemes_to_histories_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concept_schemes_to_histories_trigger AFTER DELETE ON public.concept_schemes REFERENCING OLD TABLE AS old_concept_schemes FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concept_schemes_to_histories_trigger_function();


--
-- Name: classification_tree_labels delete_concept_schemes_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concept_schemes_trigger AFTER UPDATE ON public.classification_tree_labels REFERENCING OLD TABLE AS old_classification_tree_labels NEW TABLE AS new_classification_tree_labels FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concept_schemes_trigger_function();


--
-- Name: concepts delete_concepts_to_histories_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concepts_to_histories_trigger AFTER DELETE ON public.concepts REFERENCING OLD TABLE AS old_concepts FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concepts_to_histories_trigger_function();


--
-- Name: classification_aliases delete_concepts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_concepts_trigger AFTER UPDATE ON public.classification_aliases REFERENCING OLD TABLE AS old_classification_aliases NEW TABLE AS new_classification_aliases FOR EACH STATEMENT EXECUTE FUNCTION public.delete_concepts_trigger_function();


--
-- Name: thing_translations delete_external_hashes_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_external_hashes_trigger AFTER DELETE ON public.thing_translations REFERENCING OLD TABLE AS old_thing_translations FOR EACH STATEMENT EXECUTE FUNCTION public.delete_external_hashes_trigger_1();


--
-- Name: schedules delete_schedule_occurences_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_schedule_occurences_trigger AFTER DELETE ON public.schedules REFERENCING OLD TABLE AS old_schedules FOR EACH STATEMENT EXECUTE FUNCTION public.delete_schedule_occurences_trigger();


--
-- Name: things delete_things_external_source_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_things_external_source_trigger BEFORE UPDATE OF external_key, external_source_id ON public.things FOR EACH ROW WHEN ((((old.external_key)::text IS DISTINCT FROM (new.external_key)::text) OR ((old.external_source_id IS DISTINCT FROM new.external_source_id) AND (new.external_key IS NULL) AND (new.external_source_id IS NULL)))) EXECUTE FUNCTION public.delete_things_external_source_trigger_function();


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
-- Name: classification_trees generate_classification_alias_paths_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_classification_alias_paths_trigger AFTER INSERT ON public.classification_trees FOR EACH ROW EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_2();


--
-- Name: classification_alias_paths generate_collected_classification_content_relations_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_collected_classification_content_relations_trigger AFTER INSERT ON public.classification_alias_paths REFERENCING NEW TABLE AS new_classification_alias_paths FOR EACH STATEMENT EXECUTE FUNCTION public.generate_collected_classification_content_relations_trigger_5();


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
-- Name: collections generate_collection_slug_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_collection_slug_trigger BEFORE INSERT ON public.collections FOR EACH ROW WHEN ((new.slug IS NOT NULL)) EXECUTE FUNCTION public.generate_collection_slug_trigger();


--
-- Name: content_contents generate_content_content_links_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_content_content_links_trigger AFTER INSERT ON public.content_contents REFERENCING NEW TABLE AS new_content_contents FOR EACH STATEMENT EXECUTE FUNCTION public.generate_content_content_links_trigger();


--
-- Name: users generate_my_selection_watch_list; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_my_selection_watch_list AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.generate_my_selection_watch_list();


--
-- Name: schedules generate_schedule_occurences_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER generate_schedule_occurences_trigger AFTER INSERT ON public.schedules FOR EACH ROW EXECUTE FUNCTION public.generate_schedule_occurences_trigger();


--
-- Name: things geom_simple_insert_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER geom_simple_insert_trigger BEFORE INSERT ON public.things FOR EACH ROW EXECUTE FUNCTION public.geom_simple_update();


--
-- Name: things geom_simple_update_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER geom_simple_update_trigger BEFORE UPDATE OF location, line, geom ON public.things FOR EACH ROW WHEN ((((old.location)::text IS DISTINCT FROM (new.location)::text) OR ((old.line)::text IS DISTINCT FROM (new.line)::text) OR ((old.geom)::text IS DISTINCT FROM (new.geom)::text))) EXECUTE FUNCTION public.geom_simple_update();


--
-- Name: classification_trees insert_classification_tree_order_a_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER insert_classification_tree_order_a_trigger AFTER INSERT ON public.classification_trees REFERENCING NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION public.insert_classification_trees_order_a_trigger();


--
-- Name: classification_trees insert_concept_links_trees_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER insert_concept_links_trees_trigger AFTER INSERT ON public.classification_trees REFERENCING NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION public.insert_concept_links_trees_trigger_function();


--
-- Name: classification_tree_labels insert_concept_schemes_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER insert_concept_schemes_trigger AFTER INSERT ON public.classification_tree_labels REFERENCING NEW TABLE AS new_classification_tree_labels FOR EACH STATEMENT EXECUTE FUNCTION public.insert_concept_schemes_trigger_function();


--
-- Name: classification_aliases insert_concepts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER insert_concepts_trigger AFTER INSERT ON public.classification_aliases REFERENCING NEW TABLE AS new_classification_aliases FOR EACH STATEMENT EXECUTE FUNCTION public.insert_concepts_trigger_function();


--
-- Name: thing_templates insert_thing_templates_schema_types; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER insert_thing_templates_schema_types BEFORE INSERT ON public.thing_templates FOR EACH ROW EXECUTE FUNCTION public.generate_thing_schema_types();


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
-- Name: classification_contents update_ccc_relations_transitive_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_ccc_relations_transitive_trigger AFTER UPDATE OF content_data_id, classification_id, relation ON public.classification_contents FOR EACH ROW WHEN (((old.content_data_id IS DISTINCT FROM new.content_data_id) OR (old.classification_id IS DISTINCT FROM new.classification_id) OR ((old.relation)::text IS DISTINCT FROM (new.relation)::text))) EXECUTE FUNCTION public.generate_ccc_relations_transitive_trigger_2();

ALTER TABLE public.classification_contents DISABLE TRIGGER update_ccc_relations_transitive_trigger;


--
-- Name: classification_groups update_ccc_relations_trigger_4; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_ccc_relations_trigger_4 AFTER UPDATE OF classification_id, classification_alias_id ON public.classification_groups FOR EACH ROW WHEN (((old.classification_id IS DISTINCT FROM new.classification_id) OR (old.classification_alias_id IS DISTINCT FROM new.classification_alias_id))) EXECUTE FUNCTION public.update_collected_classification_content_relations_trigger_4();


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
-- Name: classification_aliases update_classification_aliases_order_a_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_classification_aliases_order_a_trigger AFTER UPDATE ON public.classification_aliases REFERENCING OLD TABLE AS old_classification_aliases NEW TABLE AS updated_classification_aliases FOR EACH STATEMENT EXECUTE FUNCTION public.update_classification_aliases_order_a_trigger();


--
-- Name: classification_trees update_classification_tree_order_a_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_classification_tree_order_a_trigger AFTER UPDATE ON public.classification_trees REFERENCING OLD TABLE AS old_classification_trees NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION public.update_classification_trees_order_a_trigger();


--
-- Name: classification_trees update_classification_tree_tree_label_id_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_classification_tree_tree_label_id_trigger AFTER UPDATE ON public.classification_trees REFERENCING OLD TABLE AS old_classification_trees NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION public.update_classification_tree_tree_label_id_trigger();


--
-- Name: classification_alias_paths update_collected_classification_content_relations_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_collected_classification_content_relations_trigger AFTER UPDATE ON public.classification_alias_paths FOR EACH ROW EXECUTE FUNCTION public.generate_collected_classification_content_relations_trigger_3();


--
-- Name: classification_contents update_collected_classification_content_relations_trigger_1; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_collected_classification_content_relations_trigger_1 AFTER UPDATE OF content_data_id, classification_id, relation ON public.classification_contents FOR EACH ROW WHEN (((old.content_data_id IS DISTINCT FROM new.content_data_id) OR (old.classification_id IS DISTINCT FROM new.classification_id) OR ((old.relation)::text IS DISTINCT FROM (new.relation)::text))) EXECUTE FUNCTION public.generate_collected_classification_content_relations_trigger_1();


--
-- Name: collections update_collection_slug_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_collection_slug_trigger BEFORE UPDATE OF slug ON public.collections FOR EACH ROW WHEN (((new.slug IS NOT NULL) AND ((old.slug)::text IS DISTINCT FROM (new.slug)::text))) EXECUTE FUNCTION public.generate_collection_slug_trigger();


--
-- Name: classification_groups update_concept_links_groups_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_concept_links_groups_trigger AFTER UPDATE ON public.classification_groups REFERENCING OLD TABLE AS old_classification_groups NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION public.update_concept_links_groups_trigger_function();


--
-- Name: classification_trees update_concept_links_trees_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_concept_links_trees_trigger AFTER UPDATE ON public.classification_trees REFERENCING OLD TABLE AS old_classification_trees NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION public.update_concept_links_trees_trigger_function();


--
-- Name: classification_tree_labels update_concept_schemes_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_concept_schemes_trigger AFTER UPDATE ON public.classification_tree_labels REFERENCING OLD TABLE AS old_classification_tree_labels NEW TABLE AS new_classification_tree_labels FOR EACH STATEMENT EXECUTE FUNCTION public.update_concept_schemes_trigger_function();


--
-- Name: classification_aliases update_concepts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_concepts_trigger AFTER UPDATE ON public.classification_aliases REFERENCING OLD TABLE AS old_classification_aliases NEW TABLE AS new_classification_aliases FOR EACH STATEMENT EXECUTE FUNCTION public.update_concepts_trigger_function();


--
-- Name: content_contents update_content_content_links_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_content_content_links_trigger AFTER UPDATE ON public.content_contents REFERENCING OLD TABLE AS old_content_contents NEW TABLE AS new_content_contents FOR EACH STATEMENT EXECUTE FUNCTION public.generate_content_content_links_trigger2();


--
-- Name: classification_groups update_deleted_at_ccc_relations_trigger_4; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_deleted_at_ccc_relations_trigger_4 AFTER UPDATE OF deleted_at ON public.classification_groups FOR EACH ROW WHEN (((old.deleted_at IS NULL) AND (new.deleted_at IS NOT NULL))) EXECUTE FUNCTION public.delete_collected_classification_content_relations_trigger_1();


--
-- Name: users update_my_selection_watch_list; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_my_selection_watch_list AFTER UPDATE OF role_id ON public.users FOR EACH ROW WHEN ((old.role_id IS DISTINCT FROM new.role_id)) EXECUTE FUNCTION public.generate_my_selection_watch_list();


--
-- Name: schedules update_schedule_occurences_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_schedule_occurences_trigger AFTER UPDATE OF thing_id, duration, rrule, dtstart, relation, exdate, rdate ON public.schedules FOR EACH ROW WHEN (((old.thing_id IS DISTINCT FROM new.thing_id) OR (old.duration IS DISTINCT FROM new.duration) OR ((old.rrule)::text IS DISTINCT FROM (new.rrule)::text) OR (old.dtstart IS DISTINCT FROM new.dtstart) OR ((old.relation)::text IS DISTINCT FROM (new.relation)::text) OR (old.rdate IS DISTINCT FROM new.rdate) OR (old.exdate IS DISTINCT FROM new.exdate))) EXECUTE FUNCTION public.generate_schedule_occurences_trigger();


--
-- Name: thing_templates update_template_definitions_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_template_definitions_trigger AFTER UPDATE ON public.thing_templates REFERENCING OLD TABLE AS old_thing_templates NEW TABLE AS new_thing_templates FOR EACH STATEMENT EXECUTE FUNCTION public.update_template_definitions_trigger();


--
-- Name: thing_templates update_thing_templates_schema_types; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_thing_templates_schema_types BEFORE UPDATE OF template_name, schema ON public.thing_templates FOR EACH ROW WHEN ((((old.template_name)::text IS DISTINCT FROM (new.template_name)::text) OR (old.schema IS DISTINCT FROM new.schema))) EXECUTE FUNCTION public.generate_thing_schema_types();


--
-- Name: classification_groups upsert_concept_tables_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER upsert_concept_tables_trigger AFTER INSERT ON public.classification_groups REFERENCING NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION public.upsert_concept_tables_trigger_function();


--
-- Name: collected_classification_contents fk_classification_aliases; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_classification_contents
    ADD CONSTRAINT fk_classification_aliases FOREIGN KEY (classification_alias_id) REFERENCES public.classification_aliases(id) ON DELETE CASCADE;


--
-- Name: collected_classification_contents fk_classification_tree_labels; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_classification_contents
    ADD CONSTRAINT fk_classification_tree_labels FOREIGN KEY (classification_tree_label_id) REFERENCES public.classification_tree_labels(id) ON DELETE CASCADE;


--
-- Name: content_content_links fk_content_content_links_content_contents; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_content_links
    ADD CONSTRAINT fk_content_content_links_content_contents FOREIGN KEY (content_content_id) REFERENCES public.content_contents(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: external_hashes fk_external_hashes_things; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_hashes
    ADD CONSTRAINT fk_external_hashes_things FOREIGN KEY (external_source_id, external_key) REFERENCES public.things(external_source_id, external_key) ON DELETE CASCADE;


--
-- Name: things fk_rails_08fe6d1543; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.things
    ADD CONSTRAINT fk_rails_08fe6d1543 FOREIGN KEY (template_name) REFERENCES public.thing_templates(template_name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: classification_trees fk_rails_0aeb2f8fa2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_trees
    ADD CONSTRAINT fk_rails_0aeb2f8fa2 FOREIGN KEY (external_source_id) REFERENCES public.external_systems(id) ON DELETE SET NULL NOT VALID;


--
-- Name: collection_shares fk_rails_1858f5b63d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_shares
    ADD CONSTRAINT fk_rails_1858f5b63d FOREIGN KEY (user_group_id) REFERENCES public.user_groups(id) ON DELETE CASCADE;


--
-- Name: collection_concept_scheme_links fk_rails_1865a6d52b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_concept_scheme_links
    ADD CONSTRAINT fk_rails_1865a6d52b FOREIGN KEY (concept_scheme_id) REFERENCES public.concept_schemes(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: concept_links fk_rails_1c70d20c08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_links
    ADD CONSTRAINT fk_rails_1c70d20c08 FOREIGN KEY (parent_id) REFERENCES public.concepts(id) ON DELETE CASCADE;


--
-- Name: thing_histories fk_rails_2590768864; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_histories
    ADD CONSTRAINT fk_rails_2590768864 FOREIGN KEY (template_name) REFERENCES public.thing_templates(template_name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: classification_trees fk_rails_344c9a3b48; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_trees
    ADD CONSTRAINT fk_rails_344c9a3b48 FOREIGN KEY (classification_alias_id) REFERENCES public.classification_aliases(id) ON DELETE CASCADE NOT VALID;


--
-- Name: concepts fk_rails_34b6f016a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concepts
    ADD CONSTRAINT fk_rails_34b6f016a9 FOREIGN KEY (concept_scheme_id) REFERENCES public.concept_schemes(id) ON DELETE CASCADE;


--
-- Name: collection_shares fk_rails_36b2297df7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_shares
    ADD CONSTRAINT fk_rails_36b2297df7 FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: concept_schemes fk_rails_434bc563a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_schemes
    ADD CONSTRAINT fk_rails_434bc563a9 FOREIGN KEY (id) REFERENCES public.classification_tree_labels(id) ON DELETE CASCADE;


--
-- Name: user_group_users fk_rails_485739ff03; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group_users
    ADD CONSTRAINT fk_rails_485739ff03 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE NOT VALID;


--
-- Name: timeseries fk_rails_53ff16144f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timeseries
    ADD CONSTRAINT fk_rails_53ff16144f FOREIGN KEY (thing_id) REFERENCES public.things(id) ON DELETE CASCADE;


--
-- Name: watch_list_data_hashes fk_rails_5a75554f32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watch_list_data_hashes
    ADD CONSTRAINT fk_rails_5a75554f32 FOREIGN KEY (watch_list_id) REFERENCES public.collections(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: classification_trees fk_rails_617f767237; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_trees
    ADD CONSTRAINT fk_rails_617f767237 FOREIGN KEY (parent_classification_alias_id) REFERENCES public.classification_aliases(id) ON DELETE CASCADE NOT VALID;


--
-- Name: classification_contents fk_rails_6ff9fbf404; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_contents
    ADD CONSTRAINT fk_rails_6ff9fbf404 FOREIGN KEY (content_data_id) REFERENCES public.things(id) ON DELETE CASCADE NOT VALID;


--
-- Name: thing_histories fk_rails_71ac418654; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_histories
    ADD CONSTRAINT fk_rails_71ac418654 FOREIGN KEY (external_source_id) REFERENCES public.external_systems(id) ON DELETE SET NULL NOT VALID;


--
-- Name: classifications fk_rails_72385dbd06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classifications
    ADD CONSTRAINT fk_rails_72385dbd06 FOREIGN KEY (external_source_id) REFERENCES public.external_systems(id) ON DELETE SET NULL NOT VALID;


--
-- Name: classification_trees fk_rails_744c1d38fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_trees
    ADD CONSTRAINT fk_rails_744c1d38fc FOREIGN KEY (classification_tree_label_id) REFERENCES public.classification_tree_labels(id) ON DELETE CASCADE NOT VALID;


--
-- Name: classification_groups fk_rails_783650782d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_groups
    ADD CONSTRAINT fk_rails_783650782d FOREIGN KEY (classification_alias_id) REFERENCES public.classification_aliases(id) ON DELETE CASCADE NOT VALID;


--
-- Name: things fk_rails_7b61990cb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.things
    ADD CONSTRAINT fk_rails_7b61990cb0 FOREIGN KEY (external_source_id) REFERENCES public.external_systems(id) ON DELETE SET NULL NOT VALID;


--
-- Name: external_system_syncs fk_rails_8fcdea2ef6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_syncs
    ADD CONSTRAINT fk_rails_8fcdea2ef6 FOREIGN KEY (external_system_id) REFERENCES public.external_systems(id) ON DELETE CASCADE NOT VALID;


--
-- Name: content_collection_links fk_rails_9798cd1238; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_collection_links
    ADD CONSTRAINT fk_rails_9798cd1238 FOREIGN KEY (collection_id) REFERENCES public.collections(id) ON DELETE CASCADE;


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: concepts fk_rails_99594fb6b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concepts
    ADD CONSTRAINT fk_rails_99594fb6b8 FOREIGN KEY (id) REFERENCES public.classification_aliases(id) ON DELETE CASCADE;


--
-- Name: collections fk_rails_9b33697360; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT fk_rails_9b33697360 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: classification_aliases fk_rails_a7798aa495; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_aliases
    ADD CONSTRAINT fk_rails_a7798aa495 FOREIGN KEY (external_source_id) REFERENCES public.external_systems(id) ON DELETE SET NULL NOT VALID;


--
-- Name: content_collection_link_histories fk_rails_c0f274630b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_collection_link_histories
    ADD CONSTRAINT fk_rails_c0f274630b FOREIGN KEY (collection_id) REFERENCES public.collections(id) ON DELETE CASCADE;


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: classification_alias_paths_transitive fk_rails_ca1c042635; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_alias_paths_transitive
    ADD CONSTRAINT fk_rails_ca1c042635 FOREIGN KEY (classification_alias_id) REFERENCES public.classification_aliases(id) ON DELETE CASCADE NOT VALID;


--
-- Name: content_collection_link_histories fk_rails_cc667ddb92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_collection_link_histories
    ADD CONSTRAINT fk_rails_cc667ddb92 FOREIGN KEY (thing_history_id) REFERENCES public.thing_histories(id) ON DELETE CASCADE;


--
-- Name: collection_shares fk_rails_cd18bf012f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_shares
    ADD CONSTRAINT fk_rails_cd18bf012f FOREIGN KEY (collection_id) REFERENCES public.collections(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: classification_groups fk_rails_d9919e12e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_groups
    ADD CONSTRAINT fk_rails_d9919e12e6 FOREIGN KEY (classification_id) REFERENCES public.classifications(id) ON DELETE CASCADE NOT VALID;


--
-- Name: user_group_users fk_rails_da075980a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group_users
    ADD CONSTRAINT fk_rails_da075980a7 FOREIGN KEY (user_group_id) REFERENCES public.user_groups(id) ON DELETE CASCADE NOT VALID;


--
-- Name: concept_links fk_rails_dc47cbf944; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_links
    ADD CONSTRAINT fk_rails_dc47cbf944 FOREIGN KEY (child_id) REFERENCES public.concepts(id) ON DELETE CASCADE;


--
-- Name: collection_concept_scheme_links fk_rails_e331a2a8bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_concept_scheme_links
    ADD CONSTRAINT fk_rails_e331a2a8bf FOREIGN KEY (collection_id) REFERENCES public.collections(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: collection_shares fk_rails_e7eded8bbe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_shares
    ADD CONSTRAINT fk_rails_e7eded8bbe FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: content_collection_links fk_rails_eb360242ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_collection_links
    ADD CONSTRAINT fk_rails_eb360242ed FOREIGN KEY (thing_id) REFERENCES public.things(id) ON DELETE CASCADE;


--
-- Name: collections fk_rails_f092282905; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT fk_rails_f092282905 FOREIGN KEY (linked_stored_filter_id) REFERENCES public.collections(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: classification_groups fk_rails_f570600b17; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_groups
    ADD CONSTRAINT fk_rails_f570600b17 FOREIGN KEY (external_source_id) REFERENCES public.external_systems(id) ON DELETE SET NULL NOT VALID;


--
-- Name: collected_classification_contents fk_things; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_classification_contents
    ADD CONSTRAINT fk_things FOREIGN KEY (thing_id) REFERENCES public.things(id) ON DELETE CASCADE;


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
('20221202071928'),
('20221207085950'),
('20230110113327'),
('20230111134615'),
('20230123071358'),
('20230201083504'),
('20230208145904'),
('20230214091138'),
('20230223112058'),
('20230223115656'),
('20230224185643'),
('20230228085431'),
('20230303150323'),
('20230306092709'),
('20230313072638'),
('20230317083224'),
('20230321085100'),
('20230322145244'),
('20230329123152'),
('20230330081538'),
('20230403113641'),
('20230425060228'),
('20230515081146'),
('20230516132624'),
('20230517085644'),
('20230531065846'),
('20230605061741'),
('20230606085940'),
('20230615093555'),
('20230701115607'),
('20230705061652'),
('20230712062841'),
('20230718071217'),
('20230721072044'),
('20230721072045'),
('20230724083209'),
('20230802112843'),
('20230802112844'),
('20230804062814'),
('20230807063824'),
('20230809085903'),
('20230810101627'),
('20230821094137'),
('20230823081910'),
('20230824060920'),
('20231010095157'),
('20231023100607'),
('20231108115445'),
('20231109091823'),
('20231109142629'),
('20231113104134'),
('20231115104227'),
('20231122124135'),
('20231123103232'),
('20231127144259'),
('20231201083233'),
('20231220082023'),
('20240118164523'),
('20240124113601'),
('20240227133132'),
('20240311123217'),
('20240318112843'),
('20240325085848'),
('20240325103342'),
('20240326094944'),
('20240326121702'),
('20240328130446'),
('20240402073855'),
('20240405095332'),
('20240408124153'),
('20240409104345'),
('20240409105043'),
('20240415082040'),
('20240415084245'),
('20240415103014'),
('20240415124045'),
('20240423093936'),
('20240424112003'),
('20240425095608'),
('20240425100129');


