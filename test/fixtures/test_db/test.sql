--
-- PostgreSQL database dump
--

-- Dumped from database version 11.2 (Debian 11.2-1.pgdg90+1)
-- Dumped by pg_dump version 11.8 (Debian 11.8-1.pgdg100+1)

-- Started on 2020-10-30 16:01:53 CET

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
-- TOC entry 3 (class 3079 OID 22004)
-- Name: pg_phash; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_phash WITH SCHEMA public;


--
-- TOC entry 4360 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION pg_phash; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_phash IS 'support phash hamming distance calculation';


--
-- TOC entry 2 (class 3079 OID 22055)
-- Name: pg_rrule; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_rrule WITH SCHEMA public;


--
-- TOC entry 4361 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pg_rrule; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_rrule IS 'RRULE field type for PostgreSQL';


--
-- TOC entry 5 (class 3079 OID 20742)
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- TOC entry 4362 (class 0 OID 0)
-- Dependencies: 5
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- TOC entry 4 (class 3079 OID 20819)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 4363 (class 0 OID 0)
-- Dependencies: 4
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 7 (class 3079 OID 19725)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 4364 (class 0 OID 0)
-- Dependencies: 7
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- TOC entry 6 (class 3079 OID 20730)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 4365 (class 0 OID 0)
-- Dependencies: 6
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 247 (class 1259 OID 22033)
-- Name: activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activities (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    activitiable_type character varying,
    activitiable_id uuid,
    user_id uuid,
    activity_type character varying,
    data jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 208 (class 1259 OID 20981)
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 231 (class 1259 OID 21715)
-- Name: asset_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asset_contents (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    content_data_id uuid,
    content_data_type character varying,
    asset_id uuid,
    asset_type character varying,
    relation character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 229 (class 1259 OID 21693)
-- Name: assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assets (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    file character varying,
    type character varying,
    content_type character varying,
    file_size integer,
    creator_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    seen_at timestamp without time zone,
    name character varying,
    metadata jsonb,
    duplicate_check jsonb
);


--
-- TOC entry 210 (class 1259 OID 21007)
-- Name: classification_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_aliases (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
-- TOC entry 213 (class 1259 OID 21046)
-- Name: classification_tree_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_tree_labels (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    name character varying,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    internal boolean DEFAULT false,
    deleted_at timestamp without time zone,
    visibility character varying[] DEFAULT '{}'::character varying[]
);


--
-- TOC entry 212 (class 1259 OID 21032)
-- Name: classification_trees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_trees (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
-- TOC entry 243 (class 1259 OID 21993)
-- Name: classification_alias_paths; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.classification_alias_paths AS
 WITH RECURSIVE classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names) AS (
         SELECT classification_aliases.id,
            ARRAY[]::uuid[] AS ancestor_ids,
            ARRAY[classification_aliases.id] AS full_path_ids,
            ARRAY[classification_aliases.internal_name, classification_tree_labels.name] AS full_path_names
           FROM ((public.classification_trees
             JOIN public.classification_aliases ON ((classification_aliases.id = classification_trees.classification_alias_id)))
             JOIN public.classification_tree_labels ON ((classification_tree_labels.id = classification_trees.classification_tree_label_id)))
          WHERE (classification_trees.parent_classification_alias_id IS NULL)
        UNION ALL
         SELECT classification_aliases.id,
            (classification_alias_paths_1.id || classification_alias_paths_1.ancestor_ids) AS ancestor_ids,
            (classification_aliases.id || classification_alias_paths_1.full_path_ids) AS full_path_ids,
            (classification_aliases.internal_name || classification_alias_paths_1.full_path_names) AS full_path_names
           FROM ((public.classification_trees
             JOIN classification_alias_paths classification_alias_paths_1 ON ((classification_alias_paths_1.id = classification_trees.parent_classification_alias_id)))
             JOIN public.classification_aliases ON ((classification_aliases.id = classification_trees.classification_alias_id)))
        )
 SELECT classification_alias_paths.id,
    classification_alias_paths.ancestor_ids,
    classification_alias_paths.full_path_ids,
    classification_alias_paths.full_path_names
   FROM classification_alias_paths;


--
-- TOC entry 225 (class 1259 OID 21614)
-- Name: classification_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_contents (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    content_data_id uuid,
    classification_id uuid,
    tag boolean,
    classification boolean,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    relation character varying
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 211 (class 1259 OID 21017)
-- Name: classification_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_groups (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    classification_id uuid,
    classification_alias_id uuid,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- TOC entry 244 (class 1259 OID 21998)
-- Name: classification_alias_statistics; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.classification_alias_statistics AS
 WITH descendant_counts AS (
         SELECT classification_aliases_1.id,
            count(
                CASE
                    WHEN (exploded_classification_ancestors.ancestor_id IS NOT NULL) THEN 1
                    ELSE NULL::integer
                END) AS descendant_count
           FROM (public.classification_aliases classification_aliases_1
             JOIN ( SELECT unnest(classification_alias_paths.ancestor_ids) AS ancestor_id
                   FROM public.classification_alias_paths) exploded_classification_ancestors ON ((exploded_classification_ancestors.ancestor_id = classification_aliases_1.id)))
          GROUP BY classification_aliases_1.id
        ), linked_content_counts AS (
         SELECT classification_aliases_1.id,
            count(
                CASE
                    WHEN (classification_aliases_1.id IS NOT NULL) THEN 1
                    ELSE NULL::integer
                END) AS linked_content_count
           FROM (((public.classification_aliases classification_aliases_1
             JOIN public.classification_alias_paths ON ((classification_aliases_1.id = classification_alias_paths.id)))
             JOIN public.classification_groups ON ((classification_aliases_1.id = classification_groups.classification_alias_id)))
             JOIN public.classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
          GROUP BY classification_aliases_1.id
        ), descendants_linked_content_counts AS (
         SELECT exploded_classification_ancestors.ancestor_id AS id,
            count(*) AS linked_content_count
           FROM ((( SELECT unnest(classification_alias_paths.ancestor_ids) AS ancestor_id,
                    classification_alias_paths.id AS classification_alias_id
                   FROM public.classification_alias_paths) exploded_classification_ancestors
             JOIN public.classification_groups ON ((exploded_classification_ancestors.classification_alias_id = classification_groups.classification_alias_id)))
             JOIN public.classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
          GROUP BY exploded_classification_ancestors.ancestor_id
        )
 SELECT classification_aliases.id,
    COALESCE(descendant_counts.descendant_count, (0)::bigint) AS descendant_count,
    (COALESCE(linked_content_counts.linked_content_count, (0)::bigint) + COALESCE(descendants_linked_content_counts.linked_content_count, (0)::bigint)) AS linked_content_count
   FROM (((public.classification_aliases
     LEFT JOIN descendant_counts ON ((descendant_counts.id = classification_aliases.id)))
     LEFT JOIN linked_content_counts ON ((linked_content_counts.id = classification_aliases.id)))
     LEFT JOIN descendants_linked_content_counts ON ((descendants_linked_content_counts.id = classification_aliases.id)));


--
-- TOC entry 226 (class 1259 OID 21623)
-- Name: classification_content_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_content_histories (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    content_data_history_id uuid,
    classification_id uuid,
    tag boolean,
    classification boolean,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    relation character varying
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 250 (class 1259 OID 22114)
-- Name: classification_polygons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_polygons (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    admin_level integer,
    classification_alias_id uuid,
    geom public.geometry(MultiPolygon,3035),
    geog public.geography(MultiPolygon,4326),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 242 (class 1259 OID 21979)
-- Name: classification_tree_label_statistics; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.classification_tree_label_statistics AS
 WITH descendant_counts AS (
         SELECT classification_tree_labels_1.id,
            count(
                CASE
                    WHEN (classification_aliases.id IS NOT NULL) THEN 1
                    ELSE NULL::integer
                END) AS descendant_count
           FROM ((public.classification_tree_labels classification_tree_labels_1
             JOIN public.classification_trees ON ((classification_tree_labels_1.id = classification_trees.classification_tree_label_id)))
             JOIN public.classification_aliases ON ((classification_trees.classification_alias_id = classification_aliases.id)))
          GROUP BY classification_tree_labels_1.id
        ), linked_content_counts AS (
         SELECT classification_tree_labels_1.id,
            count(
                CASE
                    WHEN (classification_aliases.id IS NOT NULL) THEN 1
                    ELSE NULL::integer
                END) AS linked_content_count
           FROM ((((public.classification_tree_labels classification_tree_labels_1
             JOIN public.classification_trees ON ((classification_tree_labels_1.id = classification_trees.classification_tree_label_id)))
             JOIN public.classification_aliases ON ((classification_trees.classification_alias_id = classification_aliases.id)))
             JOIN public.classification_groups ON ((classification_aliases.id = classification_groups.classification_alias_id)))
             JOIN public.classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
          GROUP BY classification_tree_labels_1.id
        )
 SELECT classification_tree_labels.id,
    COALESCE(descendant_counts.descendant_count, (0)::bigint) AS descendant_count,
    COALESCE(linked_content_counts.linked_content_count, (0)::bigint) AS linked_content_count
   FROM ((public.classification_tree_labels
     LEFT JOIN descendant_counts ON ((descendant_counts.id = classification_tree_labels.id)))
     LEFT JOIN linked_content_counts ON ((linked_content_counts.id = classification_tree_labels.id)));


--
-- TOC entry 209 (class 1259 OID 20998)
-- Name: classifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classifications (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
-- TOC entry 228 (class 1259 OID 21672)
-- Name: content_content_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_content_histories (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    content_a_history_id uuid,
    relation_a character varying,
    content_b_history_id uuid,
    content_b_history_type character varying,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    order_a integer,
    relation_b character varying
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 227 (class 1259 OID 21661)
-- Name: content_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_contents (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    content_a_id uuid,
    relation_a character varying,
    content_b_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    order_a integer,
    relation_b character varying
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 251 (class 1259 OID 22137)
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
-- TOC entry 219 (class 1259 OID 21346)
-- Name: data_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_links (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
-- TOC entry 218 (class 1259 OID 21328)
-- Name: watch_list_data_hashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watch_list_data_hashes (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    watch_list_id uuid,
    hashable_id uuid,
    hashable_type character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 232 (class 1259 OID 21798)
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
-- TOC entry 234 (class 1259 OID 21868)
-- Name: things; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.things (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
    template_updated_at timestamp without time zone,
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
    line public.geography(LineStringZ,4326),
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
    representation_of_id uuid
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 238 (class 1259 OID 21943)
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
-- TOC entry 216 (class 1259 OID 21188)
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
-- TOC entry 215 (class 1259 OID 21186)
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
-- TOC entry 4366 (class 0 OID 0)
-- Dependencies: 215
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.delayed_jobs_id_seq OWNED BY public.delayed_jobs.id;


--
-- TOC entry 245 (class 1259 OID 22006)
-- Name: thing_duplicates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_duplicates (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    thing_id uuid,
    thing_duplicate_id uuid,
    method character varying,
    score double precision,
    false_positive boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 246 (class 1259 OID 22018)
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
-- TOC entry 240 (class 1259 OID 21957)
-- Name: external_system_syncs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_system_syncs (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
-- TOC entry 239 (class 1259 OID 21948)
-- Name: external_systems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_systems (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
    last_successful_import timestamp without time zone
);


--
-- TOC entry 241 (class 1259 OID 21970)
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
-- TOC entry 221 (class 1259 OID 21575)
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    name character varying,
    rank integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 249 (class 1259 OID 22092)
-- Name: schedule_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedule_histories (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 248 (class 1259 OID 22081)
-- Name: schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedules (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 207 (class 1259 OID 20973)
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- TOC entry 224 (class 1259 OID 21605)
-- Name: searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.searches (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
    classification_ancestors_mapping uuid[]
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 230 (class 1259 OID 21702)
-- Name: stored_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stored_filters (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
    sort_parameters jsonb
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 220 (class 1259 OID 21368)
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid,
    subscribable_id uuid,
    subscribable_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 236 (class 1259 OID 21896)
-- Name: thing_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_histories (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
    template_updated_at timestamp without time zone,
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
    line public.geography(LineStringZ,4326),
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
    representation_of_id uuid
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 237 (class 1259 OID 21908)
-- Name: thing_history_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_history_translations (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    thing_history_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    name character varying,
    description text,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 235 (class 1259 OID 21883)
-- Name: thing_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_translations (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    thing_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    name character varying,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='100', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='100');


--
-- TOC entry 223 (class 1259 OID 21596)
-- Name: user_group_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_group_users (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_group_id uuid,
    user_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 222 (class 1259 OID 21586)
-- Name: user_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_groups (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    name character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- TOC entry 214 (class 1259 OID 21116)
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
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
    unconfirmed_email character varying
);


--
-- TOC entry 233 (class 1259 OID 21860)
-- Name: watch_list_shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watch_list_shares (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    shareable_id uuid,
    watch_list_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    shareable_type character varying DEFAULT 'DataCycleCore::UserGroup'::character varying
);


--
-- TOC entry 217 (class 1259 OID 21319)
-- Name: watch_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watch_lists (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    name character varying,
    user_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    full_path character varying,
    full_path_names character varying[]
);


--
-- TOC entry 3943 (class 2604 OID 21191)
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs ALTER COLUMN id SET DEFAULT nextval('public.delayed_jobs_id_seq'::regclass);

--
-- TOC entry 4319 (class 0 OID 20981)
-- Dependencies: 208
-- Data for Name: ar_internal_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ar_internal_metadata (key, value, created_at, updated_at) FROM stdin;
environment	development	2020-10-29 13:32:46.288254	2020-10-29 13:32:46.288254
\.


--
-- TOC entry 4342 (class 0 OID 21715)
-- Dependencies: 231
-- Data for Name: asset_contents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.asset_contents (id, content_data_id, content_data_type, asset_id, asset_type, relation, seen_at, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4340 (class 0 OID 21693)
-- Dependencies: 229
-- Data for Name: assets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.assets (id, file, type, content_type, file_size, creator_id, created_at, updated_at, seen_at, name, metadata, duplicate_check) FROM stdin;
\.


--
-- TOC entry 4321 (class 0 OID 21007)
-- Dependencies: 210
-- Data for Name: classification_aliases; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classification_aliases (id, internal_name, seen_at, created_at, updated_at, external_source_id, internal, deleted_at, assignable, name_i18n, description_i18n, uri) FROM stdin;
bf248cd1-3c69-4afe-bad8-2c52018e351d	Männlich	2020-10-29 13:33:13.598442	2020-10-29 13:33:13.62526	2020-10-29 13:33:13.62526	\N	f	\N	t	{"de": "Männlich"}	{"de": "Male"}	https://schema.org/Male
111c75ee-b649-4512-8004-67b4558525f1	Weiblich	2020-10-29 13:33:13.707107	2020-10-29 13:33:13.70803	2020-10-29 13:33:13.70803	\N	f	\N	t	{"de": "Weiblich"}	{"de": "Female"}	https://schema.org/Female
f57ed69a-a085-4c87-abfa-0c689eb2318c	Montag	2020-10-29 13:33:13.729027	2020-10-29 13:33:13.729905	2020-10-29 13:33:13.729905	\N	f	\N	t	{"de": "Montag"}	{}	https://schema.org/Monday
4732d15d-1715-4336-aaa1-0a80806ca143	Dienstag	2020-10-29 13:33:13.751134	2020-10-29 13:33:13.752037	2020-10-29 13:33:13.752037	\N	f	\N	t	{"de": "Dienstag"}	{}	https://schema.org/Tuesday
d0b32309-85e3-4dbb-b41a-e43da9a61f80	Mittwoch	2020-10-29 13:33:13.76844	2020-10-29 13:33:13.769324	2020-10-29 13:33:13.769324	\N	f	\N	t	{"de": "Mittwoch"}	{}	https://schema.org/Wednesday
762fac59-1292-4671-8b6c-876943fc493e	Donnerstag	2020-10-29 13:33:13.792975	2020-10-29 13:33:13.793844	2020-10-29 13:33:13.793844	\N	f	\N	t	{"de": "Donnerstag"}	{}	https://schema.org/Thursday
5e25de13-a296-4a6e-9fa0-ca34e437fe5f	Freitag	2020-10-29 13:33:13.809365	2020-10-29 13:33:13.810243	2020-10-29 13:33:13.810243	\N	f	\N	t	{"de": "Freitag"}	{}	https://schema.org/Friday
628348b0-fae8-40b3-8732-a07e7590c047	Samstag	2020-10-29 13:33:13.831925	2020-10-29 13:33:13.832772	2020-10-29 13:33:13.832772	\N	f	\N	t	{"de": "Samstag"}	{}	https://schema.org/Saturday
c375d854-ee78-45c0-b203-1e1252ebd94b	Sonntag	2020-10-29 13:33:13.8476	2020-10-29 13:33:13.848466	2020-10-29 13:33:13.848466	\N	f	\N	t	{"de": "Sonntag"}	{}	https://schema.org/Sunday
b5997502-9de0-413b-9e96-78986b212fff	Januar	2020-10-29 13:33:13.866926	2020-10-29 13:33:13.867759	2020-10-29 13:33:13.867759	\N	f	\N	t	{"de": "Januar"}	{}	\N
23529ba4-1dc6-4cb1-bece-03e7a51633ef	Februar	2020-10-29 13:33:13.894484	2020-10-29 13:33:13.895437	2020-10-29 13:33:13.895437	\N	f	\N	t	{"de": "Februar"}	{}	\N
3ca4f33e-298e-4cbe-93c6-a10ec5d1ff0d	März	2020-10-29 13:33:13.913617	2020-10-29 13:33:13.91459	2020-10-29 13:33:13.91459	\N	f	\N	t	{"de": "März"}	{}	\N
be8bcc75-6484-4c49-b081-8fd52100ea9c	April	2020-10-29 13:33:13.930057	2020-10-29 13:33:13.931016	2020-10-29 13:33:13.931016	\N	f	\N	t	{"de": "April"}	{}	\N
d5fc4daf-a6d6-405e-bc27-fe922c30a25c	Mai	2020-10-29 13:33:13.94592	2020-10-29 13:33:13.946818	2020-10-29 13:33:13.946818	\N	f	\N	t	{"de": "Mai"}	{}	\N
1340b514-af44-4efa-b978-408efbfd3610	Juni	2020-10-29 13:33:13.962707	2020-10-29 13:33:13.963646	2020-10-29 13:33:13.963646	\N	f	\N	t	{"de": "Juni"}	{}	\N
3551d49b-003e-44ec-badf-081b733364d5	Juli	2020-10-29 13:33:13.97936	2020-10-29 13:33:13.980194	2020-10-29 13:33:13.980194	\N	f	\N	t	{"de": "Juli"}	{}	\N
8bed8d93-d68d-486d-aaae-8a010e6f2686	August	2020-10-29 13:33:13.995633	2020-10-29 13:33:13.996477	2020-10-29 13:33:13.996477	\N	f	\N	t	{"de": "August"}	{}	\N
b3ae1caf-092d-4a0b-992f-0ed423b8da1b	September	2020-10-29 13:33:14.012231	2020-10-29 13:33:14.013115	2020-10-29 13:33:14.013115	\N	f	\N	t	{"de": "September"}	{}	\N
13101455-5024-4443-a563-a3289706cdae	Oktober	2020-10-29 13:33:14.028365	2020-10-29 13:33:14.029226	2020-10-29 13:33:14.029226	\N	f	\N	t	{"de": "Oktober"}	{}	\N
d8325e1b-3fdb-4f06-a4b4-67abdd7dbf9f	November	2020-10-29 13:33:14.044393	2020-10-29 13:33:14.045214	2020-10-29 13:33:14.045214	\N	f	\N	t	{"de": "November"}	{}	\N
13dde352-7056-4d0e-8291-f4585933756f	Dezember	2020-10-29 13:33:14.060723	2020-10-29 13:33:14.061632	2020-10-29 13:33:14.061632	\N	f	\N	t	{"de": "Dezember"}	{}	\N
45da7461-120a-49f3-aec7-57312b081759	Tag 1	2020-10-29 13:33:14.080834	2020-10-29 13:33:14.081738	2020-10-29 13:33:14.081738	\N	f	\N	t	{"de": "Tag 1"}	{}	\N
a86c6cda-0577-4029-bcaf-5a6f1feaa0a3	Tag 2	2020-10-29 13:33:14.097839	2020-10-29 13:33:14.098821	2020-10-29 13:33:14.098821	\N	f	\N	t	{"de": "Tag 2"}	{}	\N
208ca653-ce4e-4be7-9a16-6da9d4ff765f	Web	2020-10-29 13:33:14.12449	2020-10-29 13:33:14.125386	2020-10-29 13:33:14.125386	\N	f	\N	t	{"de": "Web"}	{}	\N
e06e899d-b9d9-482a-891d-cdf9dfa25890	Print	2020-10-29 13:33:14.140155	2020-10-29 13:33:14.14096	2020-10-29 13:33:14.14096	\N	f	\N	t	{"de": "Print"}	{}	\N
ad305e6d-fac7-40b2-924e-90842323d490	Social Media	2020-10-29 13:33:14.156175	2020-10-29 13:33:14.156968	2020-10-29 13:33:14.156968	\N	f	\N	t	{"de": "Social Media"}	{}	\N
337edf50-8286-4b20-a476-61afd0c2f289	description	2020-10-29 13:33:14.1823	2020-10-29 13:33:14.183153	2020-10-29 13:33:14.183153	\N	f	\N	t	{"de": "description"}	{"de": "OutdoorActive"}	\N
b4da1cd0-9a32-46bd-9a3f-02e0594f1a54	text	2020-10-29 13:33:14.197761	2020-10-29 13:33:14.198642	2020-10-29 13:33:14.198642	\N	f	\N	t	{"de": "text"}	{"de": "OutdoorActive"}	\N
3521a453-44ca-467c-9a43-ef823b615adf	directions	2020-10-29 13:33:14.213533	2020-10-29 13:33:14.214358	2020-10-29 13:33:14.214358	\N	f	\N	t	{"de": "directions"}	{"de": "OutdoorActive"}	\N
4d77cc72-7c10-4703-b91d-31bff579d365	directions_public_transport	2020-10-29 13:33:14.229106	2020-10-29 13:33:14.22998	2020-10-29 13:33:14.22998	\N	f	\N	t	{"de": "directions_public_transport"}	{"de": "OutdoorActive"}	\N
5475057f-4592-412f-a79f-05e4857bdc94	parking	2020-10-29 13:33:14.245065	2020-10-29 13:33:14.245909	2020-10-29 13:33:14.245909	\N	f	\N	t	{"de": "parking"}	{"de": "OutdoorActive"}	\N
3aab0cae-82d4-4491-b6a1-f179350458d5	hours_available	2020-10-29 13:33:14.261075	2020-10-29 13:33:14.261984	2020-10-29 13:33:14.261984	\N	f	\N	t	{"de": "hours_available"}	{"de": "OutdoorActive"}	\N
56c498d9-ccf8-4365-9838-6e2d3d940b17	price	2020-10-29 13:33:14.277014	2020-10-29 13:33:14.277842	2020-10-29 13:33:14.277842	\N	f	\N	t	{"de": "price"}	{"de": "OutdoorActive"}	\N
49e05b74-9608-45e0-8384-1ee28dc49151	instructions	2020-10-29 13:33:14.293489	2020-10-29 13:33:14.294316	2020-10-29 13:33:14.294316	\N	f	\N	t	{"de": "instructions"}	{"de": "OutdoorActive"}	\N
fd540dff-9ff1-41cf-acaa-92cd09e4fb32	safety_instructions	2020-10-29 13:33:14.309532	2020-10-29 13:33:14.31033	2020-10-29 13:33:14.31033	\N	f	\N	t	{"de": "safety_instructions"}	{"de": "OutdoorActive"}	\N
f81309a1-b16b-4c82-a5f4-4b7775ded168	equipment	2020-10-29 13:33:14.325435	2020-10-29 13:33:14.326305	2020-10-29 13:33:14.326305	\N	f	\N	t	{"de": "equipment"}	{"de": "OutdoorActive"}	\N
cb42ecd7-e873-447a-b297-9ef33feb6a61	suggestion	2020-10-29 13:33:14.3419	2020-10-29 13:33:14.342934	2020-10-29 13:33:14.342934	\N	f	\N	t	{"de": "suggestion"}	{"de": "OutdoorActive"}	\N
8d735758-5980-429e-a90c-6ad822383144	additional_information	2020-10-29 13:33:14.358063	2020-10-29 13:33:14.359045	2020-10-29 13:33:14.359045	\N	f	\N	t	{"de": "additional_information"}	{"de": "OutdoorActive"}	\N
9039c96f-6318-43bd-b69a-a73578124445	AdditionalService	2020-10-29 13:33:14.374358	2020-10-29 13:33:14.375237	2020-10-29 13:33:14.375237	\N	f	\N	t	{"de": "AdditionalService"}	{"de": "Feratel"}	\N
74117005-eb2b-462f-9bba-df4b6e29e885	CurrentInformation	2020-10-29 13:33:14.397675	2020-10-29 13:33:14.398548	2020-10-29 13:33:14.398548	\N	f	\N	t	{"de": "CurrentInformation"}	{"de": "Feratel"}	\N
339779f9-5491-4fb9-97ad-48cefe8f542d	EventHeader	2020-10-29 13:33:14.413747	2020-10-29 13:33:14.414629	2020-10-29 13:33:14.414629	\N	f	\N	t	{"de": "EventHeader"}	{"de": "Feratel"}	\N
eda40c83-7adb-43a0-a58b-19dd56e4e5d9	EventHeaderShort	2020-10-29 13:33:14.429525	2020-10-29 13:33:14.430371	2020-10-29 13:33:14.430371	\N	f	\N	t	{"de": "EventHeaderShort"}	{"de": "Feratel"}	\N
5f7a33f1-2425-486b-861f-013d29eef6b3	GuestCardClassification	2020-10-29 13:33:14.445555	2020-10-29 13:33:14.446371	2020-10-29 13:33:14.446371	\N	f	\N	t	{"de": "GuestCardClassification"}	{"de": "Feratel"}	\N
c5f42523-e73c-4526-aa6e-3f294130a91d	InfrastructureLong	2020-10-29 13:33:14.461822	2020-10-29 13:33:14.462707	2020-10-29 13:33:14.462707	\N	f	\N	t	{"de": "InfrastructureLong"}	{"de": "Feratel"}	\N
fb08e633-5656-49d8-8bf1-4ff9d8700e37	InfrastructureOpeningTimes	2020-10-29 13:33:14.477667	2020-10-29 13:33:14.478604	2020-10-29 13:33:14.478604	\N	f	\N	t	{"de": "InfrastructureOpeningTimes"}	{"de": "Feratel"}	\N
01880fef-c961-4c1f-b0cb-38f18e1f20c1	InfrastructurePriceInfo	2020-10-29 13:33:14.493689	2020-10-29 13:33:14.494602	2020-10-29 13:33:14.494602	\N	f	\N	t	{"de": "InfrastructurePriceInfo"}	{"de": "Feratel"}	\N
5fb915ca-6557-4c8b-a87b-bd5aeb33ae1a	InfrastructureShort	2020-10-29 13:33:14.509799	2020-10-29 13:33:14.510779	2020-10-29 13:33:14.510779	\N	f	\N	t	{"de": "InfrastructureShort"}	{"de": "Feratel"}	\N
59434602-a0c4-43f9-ab32-3b4278c61acd	Package	2020-10-29 13:33:14.52642	2020-10-29 13:33:14.52732	2020-10-29 13:33:14.52732	\N	f	\N	t	{"de": "Package"}	{"de": "Feratel"}	\N
f3cef5c9-82e6-450d-a628-dc4d84d9e9b4	PackageContentLong	2020-10-29 13:33:14.542406	2020-10-29 13:33:14.543265	2020-10-29 13:33:14.543265	\N	f	\N	t	{"de": "PackageContentLong"}	{"de": "Feratel"}	\N
f017d4b5-5201-4824-832b-0124b2089aec	PackageShortText	2020-10-29 13:33:14.558246	2020-10-29 13:33:14.559104	2020-10-29 13:33:14.559104	\N	f	\N	t	{"de": "PackageShortText"}	{"de": "Feratel"}	\N
0930b05d-907b-466a-88a9-06fb00666d80	ProductDescription	2020-10-29 13:33:14.573889	2020-10-29 13:33:14.574762	2020-10-29 13:33:14.574762	\N	f	\N	t	{"de": "ProductDescription"}	{"de": "Feratel"}	\N
4095f332-2180-4dd9-a187-d19275328392	SEOKeywords	2020-10-29 13:33:14.589618	2020-10-29 13:33:14.590427	2020-10-29 13:33:14.590427	\N	f	\N	t	{"de": "SEOKeywords"}	{"de": "Feratel"}	\N
bdf50908-b8e2-4bdc-bca5-ddffab01d3af	ShopItemDescription	2020-10-29 13:33:14.605145	2020-10-29 13:33:14.605957	2020-10-29 13:33:14.605957	\N	f	\N	t	{"de": "ShopItemDescription"}	{"de": "Feratel"}	\N
8f62644e-ffdd-48da-a8ea-14393f146440	ServiceDescription	2020-10-29 13:33:14.620826	2020-10-29 13:33:14.621701	2020-10-29 13:33:14.621701	\N	f	\N	t	{"de": "ServiceDescription"}	{"de": "Feratel"}	\N
82e65628-d1cc-45fe-a839-5ed265a8825a	ServiceProviderArrivalVoucher	2020-10-29 13:33:14.63682	2020-10-29 13:33:14.644379	2020-10-29 13:33:14.644379	\N	f	\N	t	{"de": "ServiceProviderArrivalVoucher"}	{"de": "Feratel"}	\N
161ae833-f72a-44f3-b1e5-70ca30889e4c	ServiceProviderConditions	2020-10-29 13:33:14.660491	2020-10-29 13:33:14.661366	2020-10-29 13:33:14.661366	\N	f	\N	t	{"de": "ServiceProviderConditions"}	{"de": "Feratel"}	\N
841ad96c-2876-42b2-b96a-74d4fc054a84	ServiceProviderDescription	2020-10-29 13:33:14.676784	2020-10-29 13:33:14.677656	2020-10-29 13:33:14.677656	\N	f	\N	t	{"de": "ServiceProviderDescription"}	{"de": "Feratel"}	\N
57845206-2937-43ae-8e65-c9baecd9a251	Top-Event	2020-10-29 13:33:14.714583	2020-10-29 13:33:14.715534	2020-10-29 13:33:14.715534	\N	t	\N	t	{"de": "Top-Event"}	{}	\N
0e75411d-5018-4390-8a9b-b0635fc7952a	Local	2020-10-29 13:33:14.731538	2020-10-29 13:33:14.732439	2020-10-29 13:33:14.732439	\N	t	\N	t	{"de": "Local"}	{}	\N
bbeb21f7-3107-4be8-ad2f-8d149d60cc7f	Town	2020-10-29 13:33:14.74895	2020-10-29 13:33:14.749901	2020-10-29 13:33:14.749901	\N	t	\N	t	{"de": "Town"}	{}	\N
2537adce-6e9b-49b1-9b27-9664fc5f8050	Region	2020-10-29 13:33:14.772469	2020-10-29 13:33:14.773477	2020-10-29 13:33:14.773477	\N	t	\N	t	{"de": "Region"}	{}	\N
e9706e76-3e86-4ca3-8ff8-695dc89e601d	Subregion	2020-10-29 13:33:14.790728	2020-10-29 13:33:14.791725	2020-10-29 13:33:14.791725	\N	t	\N	t	{"de": "Subregion"}	{}	\N
679f1ab9-6628-46e4-b4f6-5cd969067936	Country	2020-10-29 13:33:14.808735	2020-10-29 13:33:14.809635	2020-10-29 13:33:14.809635	\N	t	\N	t	{"de": "Country"}	{}	\N
30185785-1ef5-49c2-865f-a17eb7d62269	Aktiv	2020-10-29 13:33:14.835158	2020-10-29 13:33:14.837031	2020-10-29 13:33:14.837031	\N	t	\N	t	{"de": "Aktiv"}	{}	\N
7ddcab5e-9a31-45c9-bd79-a4aca4fe6372	Inaktiv	2020-10-29 13:33:14.867835	2020-10-29 13:33:14.869367	2020-10-29 13:33:14.869367	\N	t	\N	t	{"de": "Inaktiv"}	{}	\N
f36964e7-bf20-4915-86a7-2f02d5958b0c	Gelöscht	2020-10-29 13:33:14.89758	2020-10-29 13:33:14.899206	2020-10-29 13:33:14.899206	\N	t	\N	t	{"de": "Gelöscht"}	{}	\N
c34e9323-a2b9-406d-b7ff-602d6eab7c4e	Aktiv	2020-10-29 13:33:14.933225	2020-10-29 13:33:14.936401	2020-10-29 13:33:14.936401	\N	t	\N	t	{"de": "Aktiv"}	{}	\N
bf9ccf9a-cd41-4964-a4e4-f0b87981b605	Inaktiv	2020-10-29 13:33:14.967025	2020-10-29 13:33:14.968613	2020-10-29 13:33:14.968613	\N	t	\N	t	{"de": "Inaktiv"}	{}	\N
f8af7274-f0df-493d-b286-c120672a2cf2	Buchbar	2020-10-29 13:33:15.008345	2020-10-29 13:33:15.009234	2020-10-29 13:33:15.009234	\N	t	\N	t	{"de": "Buchbar"}	{}	\N
ebbe1b3c-1f60-4b55-b00e-b5f82eb52b85	Nicht Buchbar	2020-10-29 13:33:15.024768	2020-10-29 13:33:15.025639	2020-10-29 13:33:15.025639	\N	t	\N	t	{"de": "Nicht Buchbar"}	{}	\N
6e4afbda-3db4-4767-82f3-d73d75bf897c	Preis pro Person	2020-10-29 13:33:15.045214	2020-10-29 13:33:15.046136	2020-10-29 13:33:15.046136	\N	t	\N	t	{"de": "Preis pro Person"}	{}	\N
f4244058-b6ac-499e-aa66-c1643475234a	Preis pro Package	2020-10-29 13:33:15.062579	2020-10-29 13:33:15.063578	2020-10-29 13:33:15.063578	\N	t	\N	t	{"de": "Preis pro Package"}	{}	\N
f4d0ca61-e879-4364-9335-c03b9ca9329a	Andorra	2020-10-29 13:33:15.083132	2020-10-29 13:33:15.084388	2020-10-29 13:33:15.084388	\N	f	\N	t	{"de": "Andorra"}	{}	\N
b248d1ee-1f1d-4a34-8927-3425482c82f7	Dänemark	2020-10-29 13:33:15.105898	2020-10-29 13:33:15.106934	2020-10-29 13:33:15.106934	\N	f	\N	t	{"de": "Dänemark"}	{}	\N
1982cb17-3eb9-4a08-91d8-f4f857533a3f	Deutschland	2020-10-29 13:33:15.123277	2020-10-29 13:33:15.124235	2020-10-29 13:33:15.124235	\N	f	\N	t	{"de": "Deutschland"}	{}	\N
2a6af101-a35c-481d-9d76-21e363c31596	Frankreich	2020-10-29 13:33:15.140287	2020-10-29 13:33:15.141182	2020-10-29 13:33:15.141182	\N	f	\N	t	{"de": "Frankreich"}	{}	\N
747e0362-b3f5-4d8e-b1c0-888e7e217dc5	Italien	2020-10-29 13:33:15.157177	2020-10-29 13:33:15.15811	2020-10-29 13:33:15.15811	\N	f	\N	t	{"de": "Italien"}	{}	\N
98f28440-8090-48ac-9e1a-056720370fcb	Kroatien	2020-10-29 13:33:15.17367	2020-10-29 13:33:15.174625	2020-10-29 13:33:15.174625	\N	f	\N	t	{"de": "Kroatien"}	{}	\N
b94e424b-8e82-4ecf-a256-99490b542d56	Liechtenstein	2020-10-29 13:33:15.190812	2020-10-29 13:33:15.191722	2020-10-29 13:33:15.191722	\N	f	\N	t	{"de": "Liechtenstein"}	{}	\N
2c921f29-3bca-4577-9eae-c6e0bc4c3a2a	Österreich	2020-10-29 13:33:15.207954	2020-10-29 13:33:15.208904	2020-10-29 13:33:15.208904	\N	f	\N	t	{"de": "Österreich"}	{}	\N
f83ae840-230f-4e7b-8c15-0b8d0453ef70	Polen	2020-10-29 13:33:15.229196	2020-10-29 13:33:15.230079	2020-10-29 13:33:15.230079	\N	f	\N	t	{"de": "Polen"}	{}	\N
afe80ac4-d82d-492a-b59c-d0f8a543bcba	Portugal	2020-10-29 13:33:15.249338	2020-10-29 13:33:15.25034	2020-10-29 13:33:15.25034	\N	f	\N	t	{"de": "Portugal"}	{}	\N
85324b6b-0d1c-4642-907e-b3bb0346e39c	Slowakei	2020-10-29 13:33:15.266505	2020-10-29 13:33:15.267484	2020-10-29 13:33:15.267484	\N	f	\N	t	{"de": "Slowakei"}	{}	\N
cf35cec9-5560-4732-a532-45783007bbc3	Slowenien	2020-10-29 13:33:15.283493	2020-10-29 13:33:15.284419	2020-10-29 13:33:15.284419	\N	f	\N	t	{"de": "Slowenien"}	{}	\N
da527921-ee5f-42d3-9d6e-c149d86b3e67	Schweiz	2020-10-29 13:33:15.300385	2020-10-29 13:33:15.301259	2020-10-29 13:33:15.301259	\N	f	\N	t	{"de": "Schweiz"}	{}	\N
302d20af-9b6d-401a-8715-8a79b9a1c53f	Schweden	2020-10-29 13:33:15.317346	2020-10-29 13:33:15.31831	2020-10-29 13:33:15.31831	\N	f	\N	t	{"de": "Schweden"}	{}	\N
996295b3-cbdb-4012-ad6d-c30c445f040a	Spanien	2020-10-29 13:33:15.341652	2020-10-29 13:33:15.342682	2020-10-29 13:33:15.342682	\N	f	\N	t	{"de": "Spanien"}	{}	\N
5b709e4a-9729-433e-84e7-d34fd380a70d	Tschechien	2020-10-29 13:33:15.358274	2020-10-29 13:33:15.359231	2020-10-29 13:33:15.359231	\N	f	\N	t	{"de": "Tschechien"}	{}	\N
3f6a502d-68a2-42f9-a193-dffe535114d7	Ungarn	2020-10-29 13:33:15.375836	2020-10-29 13:33:15.376818	2020-10-29 13:33:15.376818	\N	f	\N	t	{"de": "Ungarn"}	{}	\N
fd9f5a14-6a1e-410a-b2e6-75ea771b0825	AF	2020-10-29 13:33:15.39698	2020-10-29 13:33:15.397949	2020-10-29 13:33:15.397949	\N	f	\N	t	{"de": "AF"}	{"de": "Afghanistan"}	\N
51ee5fa7-690a-44ba-a2d3-3fafa74214c1	EG	2020-10-29 13:33:15.414474	2020-10-29 13:33:15.415442	2020-10-29 13:33:15.415442	\N	f	\N	t	{"de": "EG"}	{"de": "Ägypten"}	\N
91cc62df-9f3e-4154-9e58-9aa4c0e2ff11	AL	2020-10-29 13:33:15.432403	2020-10-29 13:33:15.433354	2020-10-29 13:33:15.433354	\N	f	\N	t	{"de": "AL"}	{"de": "Albanien"}	\N
30514366-e9a8-4e4d-94b0-35b8901e6159	DZ	2020-10-29 13:33:15.45333	2020-10-29 13:33:15.454223	2020-10-29 13:33:15.454223	\N	f	\N	t	{"de": "DZ"}	{"de": "Algerien"}	\N
951f128d-29ac-4189-81f5-8b6ab66fcf2e	VI	2020-10-29 13:33:15.472998	2020-10-29 13:33:15.473915	2020-10-29 13:33:15.473915	\N	f	\N	t	{"de": "VI"}	{"de": "Amerikanische Jungferninsel"}	\N
30a03a04-5685-47a4-a9b0-8e981f5e2e18	UM	2020-10-29 13:33:15.494311	2020-10-29 13:33:15.495282	2020-10-29 13:33:15.495282	\N	f	\N	t	{"de": "UM"}	{"de": "Amerikanische Überseeinseln, kleinere"}	\N
445f838c-0e04-43c4-aa15-5f8e38c0a2b7	AS	2020-10-29 13:33:15.51215	2020-10-29 13:33:15.513106	2020-10-29 13:33:15.513106	\N	f	\N	t	{"de": "AS"}	{"de": "Amerikanisch-Samoa"}	\N
76617b76-ffc2-43a9-a58b-463684da3f27	AD	2020-10-29 13:33:15.529451	2020-10-29 13:33:15.530397	2020-10-29 13:33:15.530397	\N	f	\N	t	{"de": "AD"}	{"de": "Andorra, Fürstentum"}	\N
fdae0a60-ce08-4b75-87df-cde67ea958de	AO	2020-10-29 13:33:15.550734	2020-10-29 13:33:15.551681	2020-10-29 13:33:15.551681	\N	f	\N	t	{"de": "AO"}	{"de": "Angola"}	\N
a4a9cf39-3944-4e9c-a0d0-55aea7939b56	AI	2020-10-29 13:33:15.567751	2020-10-29 13:33:15.568672	2020-10-29 13:33:15.568672	\N	f	\N	t	{"de": "AI"}	{"de": "Anguilla"}	\N
23ab564e-0a95-4ca3-afd9-4389ce0ff210	AG	2020-10-29 13:33:15.584716	2020-10-29 13:33:15.585615	2020-10-29 13:33:15.585615	\N	f	\N	t	{"de": "AG"}	{"de": "Antigua und Barbuda"}	\N
06191f9b-89cf-4a62-8754-5dd52a3665ed	GQ	2020-10-29 13:33:15.602703	2020-10-29 13:33:15.603731	2020-10-29 13:33:15.603731	\N	f	\N	t	{"de": "GQ"}	{"de": "Äquatorialguinea"}	\N
4f9d3ef9-3522-424e-b959-99b523b6c420	AR	2020-10-29 13:33:15.62033	2020-10-29 13:33:15.62121	2020-10-29 13:33:15.62121	\N	f	\N	t	{"de": "AR"}	{"de": "Argentinien"}	\N
fea54fd7-e4a0-4df2-a6c2-6c43ecc4a37b	AM	2020-10-29 13:33:15.638256	2020-10-29 13:33:15.639345	2020-10-29 13:33:15.639345	\N	f	\N	t	{"de": "AM"}	{"de": "Armenien"}	\N
a3374280-2d1d-4361-8046-5adbcc018636	AW	2020-10-29 13:33:15.661642	2020-10-29 13:33:15.662667	2020-10-29 13:33:15.662667	\N	f	\N	t	{"de": "AW"}	{"de": "Aruba"}	\N
a532984d-e360-46a6-a393-7e027342fba0	AZ	2020-10-29 13:33:15.679498	2020-10-29 13:33:15.680462	2020-10-29 13:33:15.680462	\N	f	\N	t	{"de": "AZ"}	{"de": "Aserbaidschan"}	\N
561a1d5c-7e3d-4219-bb78-8292abeb0b68	ET	2020-10-29 13:33:15.696972	2020-10-29 13:33:15.697932	2020-10-29 13:33:15.697932	\N	f	\N	t	{"de": "ET"}	{"de": "Äthiopien"}	\N
a94f41a7-5402-4647-a1f9-b39bb4abe148	AU	2020-10-29 13:33:15.714986	2020-10-29 13:33:15.715949	2020-10-29 13:33:15.715949	\N	f	\N	t	{"de": "AU"}	{"de": "Australien"}	\N
87667340-ffe7-4aa9-87f9-a8108befadbc	BS	2020-10-29 13:33:15.732529	2020-10-29 13:33:15.733554	2020-10-29 13:33:15.733554	\N	f	\N	t	{"de": "BS"}	{"de": "Bahamas"}	\N
9bc87ce7-8214-46d8-842c-ee471b13bf81	BH	2020-10-29 13:33:15.749597	2020-10-29 13:33:15.750602	2020-10-29 13:33:15.750602	\N	f	\N	t	{"de": "BH"}	{"de": "Bahrain"}	\N
9a5b561b-eef0-481b-8bd5-8324b404c976	BD	2020-10-29 13:33:15.772078	2020-10-29 13:33:15.773042	2020-10-29 13:33:15.773042	\N	f	\N	t	{"de": "BD"}	{"de": "Bangladesch"}	\N
342e674b-b990-4822-b95a-2b12c629aadb	BB	2020-10-29 13:33:15.79019	2020-10-29 13:33:15.79124	2020-10-29 13:33:15.79124	\N	f	\N	t	{"de": "BB"}	{"de": "Barbados"}	\N
82900adc-3257-48ab-a6b1-b5493e34ce3a	BE	2020-10-29 13:33:15.809274	2020-10-29 13:33:15.810334	2020-10-29 13:33:15.810334	\N	f	\N	t	{"de": "BE"}	{"de": "Belgien"}	\N
0b29236c-4548-4ef3-8be8-4c00858a9fc3	BZ	2020-10-29 13:33:15.837311	2020-10-29 13:33:15.838391	2020-10-29 13:33:15.838391	\N	f	\N	t	{"de": "BZ"}	{"de": "Belize"}	\N
6d4ae0da-8dcd-4ac7-b12f-a480469cfde6	BJ	2020-10-29 13:33:15.872022	2020-10-29 13:33:15.873899	2020-10-29 13:33:15.873899	\N	f	\N	t	{"de": "BJ"}	{"de": "Benin"}	\N
4629b195-4661-44aa-8f79-aff0c32836c8	BM	2020-10-29 13:33:15.903006	2020-10-29 13:33:15.90467	2020-10-29 13:33:15.90467	\N	f	\N	t	{"de": "BM"}	{"de": "Bermudas"}	\N
5983e035-79f9-4c37-ac7d-cb3073061ddf	BT	2020-10-29 13:33:15.931789	2020-10-29 13:33:15.934075	2020-10-29 13:33:15.934075	\N	f	\N	t	{"de": "BT"}	{"de": "Bhutan, Königreich"}	\N
3fa6a37d-0f4e-4401-93e0-fbad77f3aa37	BO	2020-10-29 13:33:15.967915	2020-10-29 13:33:15.969393	2020-10-29 13:33:15.969393	\N	f	\N	t	{"de": "BO"}	{"de": "Bolivien"}	\N
917ceb39-97ef-459e-bd87-a147cfaf7f58	BA	2020-10-29 13:33:16.003987	2020-10-29 13:33:16.00492	2020-10-29 13:33:16.00492	\N	f	\N	t	{"de": "BA"}	{"de": "Bosnien-Herzegowina"}	\N
f91ac06d-1e62-4851-a01b-d19ed0a46376	BW	2020-10-29 13:33:16.020552	2020-10-29 13:33:16.021587	2020-10-29 13:33:16.021587	\N	f	\N	t	{"de": "BW"}	{"de": "Botsuana"}	\N
65f1402d-f87f-41ef-abfc-33728da52900	BV	2020-10-29 13:33:16.037976	2020-10-29 13:33:16.039008	2020-10-29 13:33:16.039008	\N	f	\N	t	{"de": "BV"}	{"de": "Bouvetinseln"}	\N
22c43fad-a272-42b5-ab30-aa7982be49e8	BR	2020-10-29 13:33:16.055299	2020-10-29 13:33:16.056207	2020-10-29 13:33:16.056207	\N	f	\N	t	{"de": "BR"}	{"de": "Brasilien"}	\N
bd8c7c85-eba8-45fe-8efc-9ad6e889042a	VG	2020-10-29 13:33:16.071886	2020-10-29 13:33:16.072764	2020-10-29 13:33:16.072764	\N	f	\N	t	{"de": "VG"}	{"de": "Britische Jungferninseln"}	\N
13f4a358-0066-4996-adea-d3857c71b629	IO	2020-10-29 13:33:16.088497	2020-10-29 13:33:16.089312	2020-10-29 13:33:16.089312	\N	f	\N	t	{"de": "IO"}	{"de": "Britisches Territorium im Indischen Ozean"}	\N
d276387f-bd6e-4383-ba3d-44e5ef359f73	BN	2020-10-29 13:33:16.117762	2020-10-29 13:33:16.121899	2020-10-29 13:33:16.121899	\N	f	\N	t	{"de": "BN"}	{"de": "Brunei Darussalam"}	\N
0eef62f7-d5e0-4453-a329-c92882b30f9f	BG	2020-10-29 13:33:16.150009	2020-10-29 13:33:16.151087	2020-10-29 13:33:16.151087	\N	f	\N	t	{"de": "BG"}	{"de": "Bulgarien"}	\N
7b0f65b3-fdb6-44ac-8224-5510acd53fc2	YU	2020-10-29 13:33:16.168655	2020-10-29 13:33:16.169552	2020-10-29 13:33:16.169552	\N	f	\N	t	{"de": "YU"}	{"de": "Bundesrepublik Yugoslawien"}	\N
14f7907a-82aa-499e-a6da-dbe1b0cec4ba	BF	2020-10-29 13:33:16.185958	2020-10-29 13:33:16.186875	2020-10-29 13:33:16.186875	\N	f	\N	t	{"de": "BF"}	{"de": "Burkina Faso (ehem Obervolta)"}	\N
590e72e6-c170-43da-a020-84e542567a82	BI	2020-10-29 13:33:16.203421	2020-10-29 13:33:16.204398	2020-10-29 13:33:16.204398	\N	f	\N	t	{"de": "BI"}	{"de": "Burundi"}	\N
fabfa4e5-f28b-4cf8-9241-1b007008811d	CL	2020-10-29 13:33:16.232014	2020-10-29 13:33:16.23555	2020-10-29 13:33:16.23555	\N	f	\N	t	{"de": "CL"}	{"de": "Chile"}	\N
c4c19303-966a-4ad5-a7d6-41935c2cce59	TW	2020-10-29 13:33:16.285585	2020-10-29 13:33:16.289145	2020-10-29 13:33:16.289145	\N	f	\N	t	{"de": "TW"}	{"de": "China, Republik (Taiwan)"}	\N
21243d97-684b-4988-9c4e-616b50f2cd54	CN	2020-10-29 13:33:16.323631	2020-10-29 13:33:16.325172	2020-10-29 13:33:16.325172	\N	f	\N	t	{"de": "CN"}	{"de": "China, Volksrepublik"}	\N
d93d66b8-5172-4a30-a37e-be63993ee430	CK	2020-10-29 13:33:16.349728	2020-10-29 13:33:16.351384	2020-10-29 13:33:16.351384	\N	f	\N	t	{"de": "CK"}	{"de": "Cookinseln"}	\N
3fedc464-d5e9-4601-9b3b-94a234d7d820	CR	2020-10-29 13:33:16.37564	2020-10-29 13:33:16.377217	2020-10-29 13:33:16.377217	\N	f	\N	t	{"de": "CR"}	{"de": "Costa Rica"}	\N
4d8ada33-086a-4253-9ce6-3eec768e1f7c	DK	2020-10-29 13:33:16.401404	2020-10-29 13:33:16.403131	2020-10-29 13:33:16.403131	\N	f	\N	t	{"de": "DK"}	{"de": "Dänemark"}	\N
df48d185-7bcd-44bb-acf7-ec43457f8e02	DE	2020-10-29 13:33:16.432713	2020-10-29 13:33:16.434222	2020-10-29 13:33:16.434222	\N	f	\N	t	{"de": "DE"}	{"de": "Deutschland"}	\N
853cd528-4a57-4bbc-ab85-adc7a974f18f	DM	2020-10-29 13:33:16.458007	2020-10-29 13:33:16.459537	2020-10-29 13:33:16.459537	\N	f	\N	t	{"de": "DM"}	{"de": "Dominica"}	\N
69fbd6cc-d768-42d2-a56f-e51b46506cbc	DO	2020-10-29 13:33:16.482869	2020-10-29 13:33:16.484416	2020-10-29 13:33:16.484416	\N	f	\N	t	{"de": "DO"}	{"de": "Dominikanische Republik"}	\N
e624cd72-1cdc-4001-884a-ff657e2ec1f4	DJ	2020-10-29 13:33:16.50395	2020-10-29 13:33:16.504878	2020-10-29 13:33:16.504878	\N	f	\N	t	{"de": "DJ"}	{"de": "Dschibuti"}	\N
5e384300-4734-434d-98e5-fe9bb2c51d79	EC	2020-10-29 13:33:16.519617	2020-10-29 13:33:16.52051	2020-10-29 13:33:16.52051	\N	f	\N	t	{"de": "EC"}	{"de": "Ecuador"}	\N
3e90c9f0-1aa2-4c19-9c12-e2c8d2657b5f	SV	2020-10-29 13:33:16.535094	2020-10-29 13:33:16.535902	2020-10-29 13:33:16.535902	\N	f	\N	t	{"de": "SV"}	{"de": "El Salvador"}	\N
73464c75-923a-45d9-bd39-1332ec2ad624	CI	2020-10-29 13:33:16.550138	2020-10-29 13:33:16.551	2020-10-29 13:33:16.551	\N	f	\N	t	{"de": "CI"}	{"de": "Elfenbeinküste (Cote dlvoire)"}	\N
70a92233-3bf5-470b-afc0-ef5919903bad	ER	2020-10-29 13:33:16.566528	2020-10-29 13:33:16.567413	2020-10-29 13:33:16.567413	\N	f	\N	t	{"de": "ER"}	{"de": "Eritrea, Republik"}	\N
2765389c-f10f-4a1d-bb56-d902f597aaa1	EE	2020-10-29 13:33:16.583126	2020-10-29 13:33:16.584018	2020-10-29 13:33:16.584018	\N	f	\N	t	{"de": "EE"}	{"de": "Estland"}	\N
9f8fa9e7-4206-4244-ab24-22303eb2f4ad	FK	2020-10-29 13:33:16.59997	2020-10-29 13:33:16.600867	2020-10-29 13:33:16.600867	\N	f	\N	t	{"de": "FK"}	{"de": "Falkland Inseln (Islas Malvinas)"}	\N
310f7428-736a-4084-94d8-c5ef2baec831	FO	2020-10-29 13:33:16.616813	2020-10-29 13:33:16.617725	2020-10-29 13:33:16.617725	\N	f	\N	t	{"de": "FO"}	{"de": "Färöer"}	\N
979f3dbe-403e-4fde-ad13-ef335a9782f5	FJ	2020-10-29 13:33:16.633868	2020-10-29 13:33:16.634798	2020-10-29 13:33:16.634798	\N	f	\N	t	{"de": "FJ"}	{"de": "Fidschi"}	\N
48f10f78-627c-485c-b04e-31dce3a60d53	FI	2020-10-29 13:33:16.650266	2020-10-29 13:33:16.651072	2020-10-29 13:33:16.651072	\N	f	\N	t	{"de": "FI"}	{"de": "Finnland"}	\N
8fb6f6d8-f1dd-4076-9575-8b07e919ffb6	FR	2020-10-29 13:33:16.665368	2020-10-29 13:33:16.666178	2020-10-29 13:33:16.666178	\N	f	\N	t	{"de": "FR"}	{"de": "Frankreich"}	\N
880b1c51-b7b1-4b2b-bee7-e9d43488fe78	TF	2020-10-29 13:33:16.680354	2020-10-29 13:33:16.681215	2020-10-29 13:33:16.681215	\N	f	\N	t	{"de": "TF"}	{"de": "Französische Südgebiete"}	\N
b6dc3fc5-dad7-4c90-99e1-3cd566a18c80	GF	2020-10-29 13:33:16.698855	2020-10-29 13:33:16.699799	2020-10-29 13:33:16.699799	\N	f	\N	t	{"de": "GF"}	{"de": "Französisch-Guayana"}	\N
7289c9d8-84e9-43d3-80bb-6b72281ab803	PF	2020-10-29 13:33:16.71467	2020-10-29 13:33:16.715518	2020-10-29 13:33:16.715518	\N	f	\N	t	{"de": "PF"}	{"de": "Französisch-Polynesien"}	\N
1cd4b228-a006-44d4-96bf-8e2686c76216	GA	2020-10-29 13:33:16.731199	2020-10-29 13:33:16.732043	2020-10-29 13:33:16.732043	\N	f	\N	t	{"de": "GA"}	{"de": "Gabun"}	\N
c917f6f3-e60b-4d9d-8498-ec9b2c29db32	GM	2020-10-29 13:33:16.747515	2020-10-29 13:33:16.748386	2020-10-29 13:33:16.748386	\N	f	\N	t	{"de": "GM"}	{"de": "Gambia"}	\N
19c0dba8-9258-49ab-a5f1-791b2d58a84b	GE	2020-10-29 13:33:16.763808	2020-10-29 13:33:16.764699	2020-10-29 13:33:16.764699	\N	f	\N	t	{"de": "GE"}	{"de": "Georgien"}	\N
131fd0d9-e22e-48ea-b27c-c8bae00a615b	GH	2020-10-29 13:33:16.780142	2020-10-29 13:33:16.780983	2020-10-29 13:33:16.780983	\N	f	\N	t	{"de": "GH"}	{"de": "Ghana"}	\N
e2c73122-c4f9-480a-8615-f79a45f4a0d2	GI	2020-10-29 13:33:16.796527	2020-10-29 13:33:16.797394	2020-10-29 13:33:16.797394	\N	f	\N	t	{"de": "GI"}	{"de": "Gibraltar"}	\N
9189df52-6681-4bcb-bf53-9ddb8b04f8ca	GD	2020-10-29 13:33:16.81367	2020-10-29 13:33:16.814526	2020-10-29 13:33:16.814526	\N	f	\N	t	{"de": "GD"}	{"de": "Grenada"}	\N
5d7cde15-ba21-4e91-96a9-57582a0550bf	GR	2020-10-29 13:33:16.829133	2020-10-29 13:33:16.829983	2020-10-29 13:33:16.829983	\N	f	\N	t	{"de": "GR"}	{"de": "Griechenland"}	\N
25590caf-fb21-4b86-9ccc-ed4cafd8ce5d	GL	2020-10-29 13:33:16.855972	2020-10-29 13:33:16.859538	2020-10-29 13:33:16.859538	\N	f	\N	t	{"de": "GL"}	{"de": "Grönland"}	\N
47b98442-53df-4c6f-9fa9-3edac0a11022	GP	2020-10-29 13:33:16.904299	2020-10-29 13:33:16.906296	2020-10-29 13:33:16.906296	\N	f	\N	t	{"de": "GP"}	{"de": "Guadeloupe"}	\N
7f44cee9-db74-4787-bb0a-84ef02b846c1	GU	2020-10-29 13:33:16.928212	2020-10-29 13:33:16.929486	2020-10-29 13:33:16.929486	\N	f	\N	t	{"de": "GU"}	{"de": "Guam"}	\N
6605d208-512a-46fd-bcec-89ac1959782b	GT	2020-10-29 13:33:16.950504	2020-10-29 13:33:16.951914	2020-10-29 13:33:16.951914	\N	f	\N	t	{"de": "GT"}	{"de": "Guatemala"}	\N
3837e79c-6413-46dc-9bc3-4e69e7bf79c4	GG	2020-10-29 13:33:16.982082	2020-10-29 13:33:16.985643	2020-10-29 13:33:16.985643	\N	f	\N	t	{"de": "GG"}	{"de": "Guernsey"}	\N
c8d687bf-5b76-42e5-b072-894c28ddcaeb	GN	2020-10-29 13:33:17.027234	2020-10-29 13:33:17.028753	2020-10-29 13:33:17.028753	\N	f	\N	t	{"de": "GN"}	{"de": "Guinea"}	\N
9f8a004a-f800-4f78-8271-5b3815195cbb	GW	2020-10-29 13:33:17.047835	2020-10-29 13:33:17.04886	2020-10-29 13:33:17.04886	\N	f	\N	t	{"de": "GW"}	{"de": "Guinea-Bissau"}	\N
5f6e15a9-4a4e-4edd-9351-188f9fefd630	GY	2020-10-29 13:33:17.072828	2020-10-29 13:33:17.074662	2020-10-29 13:33:17.074662	\N	f	\N	t	{"de": "GY"}	{"de": "Guyana, Kooperative Republik"}	\N
a2142821-bda5-49d3-aeb9-fa17cbb84445	HT	2020-10-29 13:33:17.095442	2020-10-29 13:33:17.096507	2020-10-29 13:33:17.096507	\N	f	\N	t	{"de": "HT"}	{"de": "Haiti"}	\N
345dfddc-ec13-4d5b-870d-6ade12d2f4d6	HM	2020-10-29 13:33:17.115488	2020-10-29 13:33:17.116642	2020-10-29 13:33:17.116642	\N	f	\N	t	{"de": "HM"}	{"de": "Heart und McDonaldinseln"}	\N
01b4ef8b-1392-4335-8afc-84ae47f2d07a	HN	2020-10-29 13:33:17.1362	2020-10-29 13:33:17.137355	2020-10-29 13:33:17.137355	\N	f	\N	t	{"de": "HN"}	{"de": "Honduras"}	\N
9d6a8a3e-2c25-42cb-bb47-d4f50e040228	HK	2020-10-29 13:33:17.156587	2020-10-29 13:33:17.157744	2020-10-29 13:33:17.157744	\N	f	\N	t	{"de": "HK"}	{"de": "Hongkong"}	\N
5361da06-a09d-49e0-a9da-357ae588c0b0	IN	2020-10-29 13:33:17.18105	2020-10-29 13:33:17.182191	2020-10-29 13:33:17.182191	\N	f	\N	t	{"de": "IN"}	{"de": "Indien"}	\N
b4e3472c-c7d9-443d-904a-a75906ab9b56	ID	2020-10-29 13:33:17.200786	2020-10-29 13:33:17.201826	2020-10-29 13:33:17.201826	\N	f	\N	t	{"de": "ID"}	{"de": "Indonesien"}	\N
6b07934a-d97c-412b-8a29-ec82631df446	IQ	2020-10-29 13:33:17.247467	2020-10-29 13:33:17.249204	2020-10-29 13:33:17.249204	\N	f	\N	t	{"de": "IQ"}	{"de": "Irak"}	\N
01840676-cd76-448f-b3e4-c5e9519d2b5d	IR	2020-10-29 13:33:17.26902	2020-10-29 13:33:17.269972	2020-10-29 13:33:17.269972	\N	f	\N	t	{"de": "IR"}	{"de": "Iran, Islamische Republik"}	\N
49985697-10e2-4af7-b265-ae2714c461f2	IE	2020-10-29 13:33:17.285991	2020-10-29 13:33:17.286907	2020-10-29 13:33:17.286907	\N	f	\N	t	{"de": "IE"}	{"de": "Irland"}	\N
1630134f-60b1-447d-ac75-0300ea7a8a77	IS	2020-10-29 13:33:17.308703	2020-10-29 13:33:17.312353	2020-10-29 13:33:17.312353	\N	f	\N	t	{"de": "IS"}	{"de": "Island"}	\N
286e59fb-c7d8-44a5-a93b-ca99a1165135	IM	2020-10-29 13:33:17.363795	2020-10-29 13:33:17.366597	2020-10-29 13:33:17.366597	\N	f	\N	t	{"de": "IM"}	{"de": "Isle of Man"}	\N
2b11b78f-260b-4056-b2eb-d6b18352e69a	IL	2020-10-29 13:33:17.389437	2020-10-29 13:33:17.390381	2020-10-29 13:33:17.390381	\N	f	\N	t	{"de": "IL"}	{"de": "Israel"}	\N
3c3bb90f-dffc-4216-822f-e7fd6ccd47f5	IT	2020-10-29 13:33:17.410549	2020-10-29 13:33:17.411962	2020-10-29 13:33:17.411962	\N	f	\N	t	{"de": "IT"}	{"de": "Italien"}	\N
8c83a97a-4cd4-4e51-9d1b-4279adef5ca2	JM	2020-10-29 13:33:17.437433	2020-10-29 13:33:17.439194	2020-10-29 13:33:17.439194	\N	f	\N	t	{"de": "JM"}	{"de": "Jamaika"}	\N
c3fb1069-4dbb-4696-a326-c950e0025ef5	JP	2020-10-29 13:33:17.459868	2020-10-29 13:33:17.460982	2020-10-29 13:33:17.460982	\N	f	\N	t	{"de": "JP"}	{"de": "Japan"}	\N
4833cf74-cf29-4d53-b8e5-5140472efd48	YE	2020-10-29 13:33:17.479657	2020-10-29 13:33:17.480797	2020-10-29 13:33:17.480797	\N	f	\N	t	{"de": "YE"}	{"de": "Jemen"}	\N
73385252-fb0f-466c-b008-321e70cab489	JE	2020-10-29 13:33:17.499324	2020-10-29 13:33:17.500438	2020-10-29 13:33:17.500438	\N	f	\N	t	{"de": "JE"}	{"de": "Jersey"}	\N
4f748f81-0dcb-4c1f-9fcb-9b3aa4beb721	JO	2020-10-29 13:33:17.518688	2020-10-29 13:33:17.519801	2020-10-29 13:33:17.519801	\N	f	\N	t	{"de": "JO"}	{"de": "Jordanien"}	\N
11d4842d-b7df-4ad5-9edc-a26adc3f84d1	KY	2020-10-29 13:33:17.539001	2020-10-29 13:33:17.540154	2020-10-29 13:33:17.540154	\N	f	\N	t	{"de": "KY"}	{"de": "Kaimaninseln"}	\N
046a6186-bc15-469d-b4bf-9fb6fae6de60	KH	2020-10-29 13:33:17.559051	2020-10-29 13:33:17.560121	2020-10-29 13:33:17.560121	\N	f	\N	t	{"de": "KH"}	{"de": "Kambodscha"}	\N
102ff072-00bc-4c23-ada0-ec20e261a966	CM	2020-10-29 13:33:17.578798	2020-10-29 13:33:17.579918	2020-10-29 13:33:17.579918	\N	f	\N	t	{"de": "CM"}	{"de": "Kamerun"}	\N
82b864e5-a3bf-43c5-a843-0d9271c176b9	CA	2020-10-29 13:33:17.598545	2020-10-29 13:33:17.599656	2020-10-29 13:33:17.599656	\N	f	\N	t	{"de": "CA"}	{"de": "Kanada"}	\N
b6687c63-d127-4a14-ab4b-6eae3c2a64c7	CV	2020-10-29 13:33:17.623268	2020-10-29 13:33:17.626865	2020-10-29 13:33:17.626865	\N	f	\N	t	{"de": "CV"}	{"de": "Kap Verde"}	\N
6247e58b-3251-4938-a4ea-8991fd31a87e	KZ	2020-10-29 13:33:17.672855	2020-10-29 13:33:17.674753	2020-10-29 13:33:17.674753	\N	f	\N	t	{"de": "KZ"}	{"de": "Kasachstan"}	\N
64a8381f-e0a5-47eb-bb59-899330f0c57b	QA	2020-10-29 13:33:17.69443	2020-10-29 13:33:17.695437	2020-10-29 13:33:17.695437	\N	f	\N	t	{"de": "QA"}	{"de": "Katar (Qatari)"}	\N
59d21e6c-7d7a-427c-9c6d-48605787a79a	KE	2020-10-29 13:33:17.712542	2020-10-29 13:33:17.713569	2020-10-29 13:33:17.713569	\N	f	\N	t	{"de": "KE"}	{"de": "Kenia"}	\N
29fe6d08-4246-41b3-8184-34be970331f2	KG	2020-10-29 13:33:17.731277	2020-10-29 13:33:17.732378	2020-10-29 13:33:17.732378	\N	f	\N	t	{"de": "KG"}	{"de": "Kirgisistan"}	\N
46897f07-74ef-4d26-b978-91a379908542	KI	2020-10-29 13:33:17.750943	2020-10-29 13:33:17.751942	2020-10-29 13:33:17.751942	\N	f	\N	t	{"de": "KI"}	{"de": "Kiribati, Republik"}	\N
09216daa-8fdc-41f6-99d4-3b90ad48427f	CC	2020-10-29 13:33:17.768598	2020-10-29 13:33:17.769607	2020-10-29 13:33:17.769607	\N	f	\N	t	{"de": "CC"}	{"de": "Kokosinseln"}	\N
23f0e823-3359-4f85-9153-efac7cd00df7	CO	2020-10-29 13:33:17.787254	2020-10-29 13:33:17.788183	2020-10-29 13:33:17.788183	\N	f	\N	t	{"de": "CO"}	{"de": "Kolumbien"}	\N
d1b66578-0e58-47df-9bc3-96b0aedce23f	KM	2020-10-29 13:33:17.805705	2020-10-29 13:33:17.806676	2020-10-29 13:33:17.806676	\N	f	\N	t	{"de": "KM"}	{"de": "Komoren, Islamische Bundesrepublik"}	\N
835249c6-2290-46f0-b61f-ae710a6da88c	CD	2020-10-29 13:33:17.824126	2020-10-29 13:33:17.825083	2020-10-29 13:33:17.825083	\N	f	\N	t	{"de": "CD"}	{"de": "Kongo, Demokratische Republik (ehem Zaire)"}	\N
253f2092-d981-466f-aae5-7ff01e386e36	ZR	2020-10-29 13:33:17.842888	2020-10-29 13:33:17.844109	2020-10-29 13:33:17.844109	\N	f	\N	t	{"de": "ZR"}	{"de": "Kongo, Demokratische Republik (ex-Zaire)"}	\N
aeeced19-e7b4-40ea-8446-7af5d670b735	CG	2020-10-29 13:33:17.863293	2020-10-29 13:33:17.86444	2020-10-29 13:33:17.86444	\N	f	\N	t	{"de": "CG"}	{"de": "Kongo, Republik"}	\N
a18568f2-dfa0-4378-a99e-780db156f192	KP	2020-10-29 13:33:17.884099	2020-10-29 13:33:17.885337	2020-10-29 13:33:17.885337	\N	f	\N	t	{"de": "KP"}	{"de": "Korea, Demokratische Volksrepublik"}	\N
a31fbd77-f197-4d47-8205-10f1830656fc	KR	2020-10-29 13:33:17.907949	2020-10-29 13:33:17.909108	2020-10-29 13:33:17.909108	\N	f	\N	t	{"de": "KR"}	{"de": "Korea, Republik"}	\N
c14ce860-8653-4e5c-9a8e-4fadaa1c4cff	RK	2020-10-29 13:33:17.929214	2020-10-29 13:33:17.930547	2020-10-29 13:33:17.930547	\N	f	\N	t	{"de": "RK"}	{"de": "Kosovo"}	\N
5acf2e9a-8cbd-4eb8-964b-efdb84ba4567	HR	2020-10-29 13:33:17.953193	2020-10-29 13:33:17.95449	2020-10-29 13:33:17.95449	\N	f	\N	t	{"de": "HR"}	{"de": "Kroatien"}	\N
86f82a47-c5e3-4a9d-9292-99387fbe9adb	CU	2020-10-29 13:33:17.976756	2020-10-29 13:33:17.977955	2020-10-29 13:33:17.977955	\N	f	\N	t	{"de": "CU"}	{"de": "Kuba"}	\N
5bceef0b-98c1-4787-bbc6-33feb410844b	KW	2020-10-29 13:33:18.002138	2020-10-29 13:33:18.003638	2020-10-29 13:33:18.003638	\N	f	\N	t	{"de": "KW"}	{"de": "Kuwait"}	\N
fd14f83d-86d0-4864-ba9a-a74af0c39413	LA	2020-10-29 13:33:18.020753	2020-10-29 13:33:18.021588	2020-10-29 13:33:18.021588	\N	f	\N	t	{"de": "LA"}	{"de": "Laos, Demokratische Volksrepublik"}	\N
fef44cc5-3c2f-4202-89c9-291522c62728	LS	2020-10-29 13:33:18.037013	2020-10-29 13:33:18.037843	2020-10-29 13:33:18.037843	\N	f	\N	t	{"de": "LS"}	{"de": "Lesotho, Königreich"}	\N
bfd59454-c187-4893-9ad2-a11664d95770	LV	2020-10-29 13:33:18.077459	2020-10-29 13:33:18.078996	2020-10-29 13:33:18.078996	\N	f	\N	t	{"de": "LV"}	{"de": "Lettland"}	\N
62b9ea7c-4d9b-4ffb-9384-ee4e6f712cf4	LB	2020-10-29 13:33:18.097872	2020-10-29 13:33:18.098909	2020-10-29 13:33:18.098909	\N	f	\N	t	{"de": "LB"}	{"de": "Libanon"}	\N
be874081-1efd-4544-aba1-f7fe31775bd3	LR	2020-10-29 13:33:18.138976	2020-10-29 13:33:18.142462	2020-10-29 13:33:18.142462	\N	f	\N	t	{"de": "LR"}	{"de": "Liberia"}	\N
d33c4cc3-a89e-459a-a809-6126c0cfb7c2	LY	2020-10-29 13:33:18.180427	2020-10-29 13:33:18.181969	2020-10-29 13:33:18.181969	\N	f	\N	t	{"de": "LY"}	{"de": "Libysch-Arabische Volks-Jamahiria, Sozialistische"}	\N
93a436d4-74a4-4bff-90ea-4f3887644cfe	LI	2020-10-29 13:33:18.202233	2020-10-29 13:33:18.203507	2020-10-29 13:33:18.203507	\N	f	\N	t	{"de": "LI"}	{"de": "Liechtenstein"}	\N
80f58998-61ab-4c04-9f72-34c05b4de5e0	LT	2020-10-29 13:33:18.224204	2020-10-29 13:33:18.22545	2020-10-29 13:33:18.22545	\N	f	\N	t	{"de": "LT"}	{"de": "Litauen"}	\N
b35c32a5-89a1-4446-892b-1ba85490ed92	LU	2020-10-29 13:33:18.244539	2020-10-29 13:33:18.245729	2020-10-29 13:33:18.245729	\N	f	\N	t	{"de": "LU"}	{"de": "Luxemburg"}	\N
b198cfbc-31fe-4bcf-90c1-3db9fa17839b	MO	2020-10-29 13:33:18.264708	2020-10-29 13:33:18.265692	2020-10-29 13:33:18.265692	\N	f	\N	t	{"de": "MO"}	{"de": "Macau (Aomen)"}	\N
2e7532ed-ccac-4c4e-b425-a36673db68b8	MG	2020-10-29 13:33:18.280748	2020-10-29 13:33:18.281482	2020-10-29 13:33:18.281482	\N	f	\N	t	{"de": "MG"}	{"de": "Madagaskar"}	\N
818d2413-79ab-4d2b-8726-549fc4bc892a	MW	2020-10-29 13:33:18.297334	2020-10-29 13:33:18.298092	2020-10-29 13:33:18.298092	\N	f	\N	t	{"de": "MW"}	{"de": "Malawi"}	\N
e3dc7401-0d98-45d0-829c-093af57ca1d7	MY	2020-10-29 13:33:18.31151	2020-10-29 13:33:18.312245	2020-10-29 13:33:18.312245	\N	f	\N	t	{"de": "MY"}	{"de": "Malaysia"}	\N
f41166f1-802b-4071-b582-95310684117a	MV	2020-10-29 13:33:18.325899	2020-10-29 13:33:18.326659	2020-10-29 13:33:18.326659	\N	f	\N	t	{"de": "MV"}	{"de": "Malediven"}	\N
f0ae6ef3-d4fa-4a4b-9116-d02658f6b9df	ML	2020-10-29 13:33:18.341128	2020-10-29 13:33:18.34203	2020-10-29 13:33:18.34203	\N	f	\N	t	{"de": "ML"}	{"de": "Mali"}	\N
3193afe6-9274-47b8-b936-413630e5753a	MT	2020-10-29 13:33:18.363394	2020-10-29 13:33:18.366572	2020-10-29 13:33:18.366572	\N	f	\N	t	{"de": "MT"}	{"de": "Malta"}	\N
e622c6fa-a84d-4208-b278-e6e1e2e154c7	MA	2020-10-29 13:33:18.391954	2020-10-29 13:33:18.392945	2020-10-29 13:33:18.392945	\N	f	\N	t	{"de": "MA"}	{"de": "Marokko"}	\N
0707a602-c944-472c-810e-5377f0035909	MH	2020-10-29 13:33:18.409476	2020-10-29 13:33:18.410338	2020-10-29 13:33:18.410338	\N	f	\N	t	{"de": "MH"}	{"de": "Marshallinseln, Republik der"}	\N
61f4ccb3-15f1-4969-bc2d-eb774f99a6cd	MQ	2020-10-29 13:33:18.4256	2020-10-29 13:33:18.426428	2020-10-29 13:33:18.426428	\N	f	\N	t	{"de": "MQ"}	{"de": "Martinique"}	\N
d4e70a81-279c-4843-b1a1-ac472aa3e9cc	MR	2020-10-29 13:33:18.441047	2020-10-29 13:33:18.441856	2020-10-29 13:33:18.441856	\N	f	\N	t	{"de": "MR"}	{"de": "Mauretanien"}	\N
18248783-e520-4291-b0bf-d78a5b4e03cc	MU	2020-10-29 13:33:18.457312	2020-10-29 13:33:18.458139	2020-10-29 13:33:18.458139	\N	f	\N	t	{"de": "MU"}	{"de": "Mauritius"}	\N
5f0f395d-81af-41ff-a79c-2daa7d3fdec1	YT	2020-10-29 13:33:18.472779	2020-10-29 13:33:18.47355	2020-10-29 13:33:18.47355	\N	f	\N	t	{"de": "YT"}	{"de": "Mayotte"}	\N
813a3766-2cc7-400a-8ca3-504a94ea8d46	MK	2020-10-29 13:33:18.505316	2020-10-29 13:33:18.506534	2020-10-29 13:33:18.506534	\N	f	\N	t	{"de": "MK"}	{"de": "Mazedonien (ehem jugoslawische Republik)"}	\N
9b305531-f99d-49b4-9285-2a07ca7f16de	MX	2020-10-29 13:33:18.525671	2020-10-29 13:33:18.526861	2020-10-29 13:33:18.526861	\N	f	\N	t	{"de": "MX"}	{"de": "Mexiko"}	\N
bda90623-3298-4d31-9d1a-a4232138a5c9	FM	2020-10-29 13:33:18.543946	2020-10-29 13:33:18.544875	2020-10-29 13:33:18.544875	\N	f	\N	t	{"de": "FM"}	{"de": "Mikronesien, Föderierte Staaten von"}	\N
2ec93c5e-0a9b-4ec9-8151-b9514d2cf522	MC	2020-10-29 13:33:18.561329	2020-10-29 13:33:18.562236	2020-10-29 13:33:18.562236	\N	f	\N	t	{"de": "MC"}	{"de": "Monaco"}	\N
aadeed45-9435-466c-81c5-c26db07327f2	MN	2020-10-29 13:33:18.579232	2020-10-29 13:33:18.580194	2020-10-29 13:33:18.580194	\N	f	\N	t	{"de": "MN"}	{"de": "Mongolei"}	\N
29d094a1-639b-4183-85a5-edf40ec6670b	MS	2020-10-29 13:33:18.596765	2020-10-29 13:33:18.597702	2020-10-29 13:33:18.597702	\N	f	\N	t	{"de": "MS"}	{"de": "Montserrat"}	\N
0a1cc10a-42c5-472a-996e-617c7c24b51a	MZ	2020-10-29 13:33:18.619127	2020-10-29 13:33:18.620008	2020-10-29 13:33:18.620008	\N	f	\N	t	{"de": "MZ"}	{"de": "Mosambik"}	\N
1403b80e-53e8-41c9-8d0d-45cfdeacfbff	MM	2020-10-29 13:33:18.642105	2020-10-29 13:33:18.643202	2020-10-29 13:33:18.643202	\N	f	\N	t	{"de": "MM"}	{"de": "Myanmar (ehem Birma / Burma)"}	\N
3a68f1d3-8507-4b3c-a0bd-74d4d64b830f	NA	2020-10-29 13:33:18.690037	2020-10-29 13:33:18.693668	2020-10-29 13:33:18.693668	\N	f	\N	t	{"de": "NA"}	{"de": "Namibia"}	\N
4f8713d2-1080-4a6a-8f7d-dcec346d7ff4	NR	2020-10-29 13:33:18.725918	2020-10-29 13:33:18.727258	2020-10-29 13:33:18.727258	\N	f	\N	t	{"de": "NR"}	{"de": "Nauru"}	\N
cc55150d-3ead-48dd-a484-ee194acb5984	NP	2020-10-29 13:33:18.748832	2020-10-29 13:33:18.750159	2020-10-29 13:33:18.750159	\N	f	\N	t	{"de": "NP"}	{"de": "Nepal"}	\N
45a51ead-4ecd-4422-9462-fac73395ac67	NC	2020-10-29 13:33:18.770841	2020-10-29 13:33:18.772271	2020-10-29 13:33:18.772271	\N	f	\N	t	{"de": "NC"}	{"de": "Neukaledonien"}	\N
29cc7444-8547-47a8-b3cc-dc2331543e9c	NZ	2020-10-29 13:33:18.795986	2020-10-29 13:33:18.80199	2020-10-29 13:33:18.80199	\N	f	\N	t	{"de": "NZ"}	{"de": "Neuseeland"}	\N
c60cacdf-ee5d-4671-b17b-6a283e9cde23	NI	2020-10-29 13:33:18.827797	2020-10-29 13:33:18.829296	2020-10-29 13:33:18.829296	\N	f	\N	t	{"de": "NI"}	{"de": "Nicaragua"}	\N
ee7e929b-05e7-44e6-ac90-906a2eb1cc30	NL	2020-10-29 13:33:18.852142	2020-10-29 13:33:18.853272	2020-10-29 13:33:18.853272	\N	f	\N	t	{"de": "NL"}	{"de": "Niederlande"}	\N
7ef35c04-22d6-49f8-ae00-1ad9ce9711c1	AN	2020-10-29 13:33:18.869495	2020-10-29 13:33:18.870426	2020-10-29 13:33:18.870426	\N	f	\N	t	{"de": "AN"}	{"de": "Niederländische Antillen"}	\N
87d5ff49-844c-4243-b4ff-84f64dc963a1	NE	2020-10-29 13:33:18.884882	2020-10-29 13:33:18.885633	2020-10-29 13:33:18.885633	\N	f	\N	t	{"de": "NE"}	{"de": "Niger"}	\N
7088fb70-62d1-4017-b3fc-3d776f9cb4b6	NG	2020-10-29 13:33:18.899798	2020-10-29 13:33:18.900518	2020-10-29 13:33:18.900518	\N	f	\N	t	{"de": "NG"}	{"de": "Nigeria"}	\N
34f67b13-7d29-47ae-93a9-911818b2d42f	NU	2020-10-29 13:33:18.914262	2020-10-29 13:33:18.914989	2020-10-29 13:33:18.914989	\N	f	\N	t	{"de": "NU"}	{"de": "Niueinseln"}	\N
8f918ffa-d8cb-4772-aee6-0fbad308a9a8	MP	2020-10-29 13:33:18.928717	2020-10-29 13:33:18.929443	2020-10-29 13:33:18.929443	\N	f	\N	t	{"de": "MP"}	{"de": "Nördliche Marianen, Commenwealth der"}	\N
1aec1e8a-1fd8-4df2-a22d-7c52e3923c49	NF	2020-10-29 13:33:18.943588	2020-10-29 13:33:18.944296	2020-10-29 13:33:18.944296	\N	f	\N	t	{"de": "NF"}	{"de": "Norfolkinseln"}	\N
afc00d30-c4e4-4767-b20a-380f339e2c91	NO	2020-10-29 13:33:18.958747	2020-10-29 13:33:18.959497	2020-10-29 13:33:18.959497	\N	f	\N	t	{"de": "NO"}	{"de": "Norwegen"}	\N
7af786a2-a968-4476-afb2-198f9148f41d	OM	2020-10-29 13:33:18.973679	2020-10-29 13:33:18.974412	2020-10-29 13:33:18.974412	\N	f	\N	t	{"de": "OM"}	{"de": "Oman"}	\N
56f6ba28-14c3-435a-ad2f-3b5e7e9852b9	AT	2020-10-29 13:33:18.987989	2020-10-29 13:33:18.988705	2020-10-29 13:33:18.988705	\N	f	\N	t	{"de": "AT"}	{"de": "Österreich"}	\N
19fd4e36-6f63-46a5-831f-b31b5ba51b07	TP	2020-10-29 13:33:19.002463	2020-10-29 13:33:19.003269	2020-10-29 13:33:19.003269	\N	f	\N	t	{"de": "TP"}	{"de": "Osttimor"}	\N
be89bbb0-cccc-480e-87ec-fd708cad7e64	PK	2020-10-29 13:33:19.027765	2020-10-29 13:33:19.029033	2020-10-29 13:33:19.029033	\N	f	\N	t	{"de": "PK"}	{"de": "Pakistan"}	\N
73e6fd48-def4-4e8c-8e4d-d892091d2789	PS	2020-10-29 13:33:19.047212	2020-10-29 13:33:19.048242	2020-10-29 13:33:19.048242	\N	f	\N	t	{"de": "PS"}	{"de": "Palästina"}	\N
313a6f52-df34-4fae-93b9-41bad061a64b	PW	2020-10-29 13:33:19.065624	2020-10-29 13:33:19.066557	2020-10-29 13:33:19.066557	\N	f	\N	t	{"de": "PW"}	{"de": "Palau, Republik"}	\N
a42a9cdc-6a4d-4270-b81e-20e4252f917c	PA	2020-10-29 13:33:19.083514	2020-10-29 13:33:19.084535	2020-10-29 13:33:19.084535	\N	f	\N	t	{"de": "PA"}	{"de": "Panama"}	\N
427ebf7c-2ec6-4385-ac09-89a4612f5192	PG	2020-10-29 13:33:19.102093	2020-10-29 13:33:19.103045	2020-10-29 13:33:19.103045	\N	f	\N	t	{"de": "PG"}	{"de": "Papua-Neuguinea"}	\N
6db5985f-c130-4ba7-9dd9-587b934acc60	PY	2020-10-29 13:33:19.120283	2020-10-29 13:33:19.121334	2020-10-29 13:33:19.121334	\N	f	\N	t	{"de": "PY"}	{"de": "Paraguay"}	\N
3f6b6cdd-4f8f-4e37-9344-14e632e62d4f	PE	2020-10-29 13:33:19.139887	2020-10-29 13:33:19.140954	2020-10-29 13:33:19.140954	\N	f	\N	t	{"de": "PE"}	{"de": "Peru"}	\N
7d5bdde6-1e08-4e7b-ae08-e915c380c45d	PH	2020-10-29 13:33:19.156322	2020-10-29 13:33:19.157116	2020-10-29 13:33:19.157116	\N	f	\N	t	{"de": "PH"}	{"de": "Philippinen"}	\N
efc6869d-f0b6-4c83-bf53-f6caeb58ddc3	PN	2020-10-29 13:33:19.171949	2020-10-29 13:33:19.172781	2020-10-29 13:33:19.172781	\N	f	\N	t	{"de": "PN"}	{"de": "Pitcairninseln"}	\N
e9d23551-dfc1-420a-af71-0dc21ca5aa71	PL	2020-10-29 13:33:19.187549	2020-10-29 13:33:19.188398	2020-10-29 13:33:19.188398	\N	f	\N	t	{"de": "PL"}	{"de": "Polen"}	\N
96cf989f-92d7-4f8e-b2ea-5dd929b9c8af	PT	2020-10-29 13:33:19.203828	2020-10-29 13:33:19.204682	2020-10-29 13:33:19.204682	\N	f	\N	t	{"de": "PT"}	{"de": "Portugal"}	\N
d1d4421f-e219-423b-bc52-120bb3047a8d	PR	2020-10-29 13:33:19.219874	2020-10-29 13:33:19.220738	2020-10-29 13:33:19.220738	\N	f	\N	t	{"de": "PR"}	{"de": "Puerto Rico"}	\N
7efabcd9-7411-4ebc-a698-f14efc23e811	MD	2020-10-29 13:33:19.235475	2020-10-29 13:33:19.236248	2020-10-29 13:33:19.236248	\N	f	\N	t	{"de": "MD"}	{"de": "Republik, Moldau"}	\N
225d58ba-0e4f-406d-a2b1-9ad82af5af27	ME	2020-10-29 13:33:19.252679	2020-10-29 13:33:19.253407	2020-10-29 13:33:19.253407	\N	f	\N	t	{"de": "ME"}	{"de": "Republik Montenegro"}	\N
2845803b-cab7-45d2-a367-7941401945ab	RS	2020-10-29 13:33:19.2674	2020-10-29 13:33:19.268177	2020-10-29 13:33:19.268177	\N	f	\N	t	{"de": "RS"}	{"de": "Republik Serbien"}	\N
ae377184-38f8-4538-b4af-8a0146bb1c7a	RW	2020-10-29 13:33:19.282266	2020-10-29 13:33:19.283025	2020-10-29 13:33:19.283025	\N	f	\N	t	{"de": "RW"}	{"de": "Ruanda"}	\N
3b91ce94-5fd9-4d87-a3fe-66d4fc4f074f	RO	2020-10-29 13:33:19.297534	2020-10-29 13:33:19.298268	2020-10-29 13:33:19.298268	\N	f	\N	t	{"de": "RO"}	{"de": "Rumänien"}	\N
d8408818-8026-4db5-be2a-1c31a38f7d81	RU	2020-10-29 13:33:19.312929	2020-10-29 13:33:19.313799	2020-10-29 13:33:19.313799	\N	f	\N	t	{"de": "RU"}	{"de": "Russische Föderation"}	\N
f0e6aa74-b56a-496b-b3ca-ca32cfe31e6d	SB	2020-10-29 13:33:19.355026	2020-10-29 13:33:19.35899	2020-10-29 13:33:19.35899	\N	f	\N	t	{"de": "SB"}	{"de": "Salomonen"}	\N
72135b47-561d-4428-abd7-ce81fb18343d	ZM	2020-10-29 13:33:19.388991	2020-10-29 13:33:19.390793	2020-10-29 13:33:19.390793	\N	f	\N	t	{"de": "ZM"}	{"de": "Sambia"}	\N
f21b218e-465d-4d3b-ae47-d795e4dce063	WS	2020-10-29 13:33:19.424991	2020-10-29 13:33:19.426784	2020-10-29 13:33:19.426784	\N	f	\N	t	{"de": "WS"}	{"de": "Samoa (Westsamoa)"}	\N
a32bf634-7a3e-4ed4-a582-a8837bbc1d8e	ST	2020-10-29 13:33:19.464977	2020-10-29 13:33:19.467436	2020-10-29 13:33:19.467436	\N	f	\N	t	{"de": "ST"}	{"de": "São Tomé und Principe, Demokratische Republik"}	\N
b9dd485e-4026-4b05-ab15-e15637450a99	SA	2020-10-29 13:33:19.494111	2020-10-29 13:33:19.495625	2020-10-29 13:33:19.495625	\N	f	\N	t	{"de": "SA"}	{"de": "Saudi Arabien"}	\N
bc62f3f9-7185-482f-a071-fd19a69859fb	SE	2020-10-29 13:33:19.524612	2020-10-29 13:33:19.526088	2020-10-29 13:33:19.526088	\N	f	\N	t	{"de": "SE"}	{"de": "Schweden"}	\N
625b5c44-4ffc-45d0-aa99-dca6b553f80d	CH	2020-10-29 13:33:19.550996	2020-10-29 13:33:19.553113	2020-10-29 13:33:19.553113	\N	f	\N	t	{"de": "CH"}	{"de": "Schweiz"}	\N
5d1f456c-146f-4952-80b4-bddfbb41923d	SN	2020-10-29 13:33:19.577885	2020-10-29 13:33:19.579358	2020-10-29 13:33:19.579358	\N	f	\N	t	{"de": "SN"}	{"de": "Senegal"}	\N
377a1a0d-aa50-437b-a852-78f29ff569d8	SC	2020-10-29 13:33:19.603381	2020-10-29 13:33:19.604836	2020-10-29 13:33:19.604836	\N	f	\N	t	{"de": "SC"}	{"de": "Seychellen"}	\N
554412f1-9f39-4d08-a183-7eb70f7bcb18	SL	2020-10-29 13:33:19.629046	2020-10-29 13:33:19.630573	2020-10-29 13:33:19.630573	\N	f	\N	t	{"de": "SL"}	{"de": "Sierra Leone"}	\N
4592bfe0-e72d-46df-8a97-f074eaecc7fe	ZW	2020-10-29 13:33:19.654161	2020-10-29 13:33:19.655597	2020-10-29 13:33:19.655597	\N	f	\N	t	{"de": "ZW"}	{"de": "Simbabwe"}	\N
670b7372-f05c-4cb6-a8b0-2e42cfa99208	SG	2020-10-29 13:33:19.679905	2020-10-29 13:33:19.6814	2020-10-29 13:33:19.6814	\N	f	\N	t	{"de": "SG"}	{"de": "Singapur"}	\N
4146a53f-5166-4ad8-9387-bc6833d341ab	SK	2020-10-29 13:33:19.704966	2020-10-29 13:33:19.706405	2020-10-29 13:33:19.706405	\N	f	\N	t	{"de": "SK"}	{"de": "Slowakische Republik"}	\N
956fa2ed-8c30-4195-ab10-48acaaea9e43	SI	2020-10-29 13:33:19.730313	2020-10-29 13:33:19.731796	2020-10-29 13:33:19.731796	\N	f	\N	t	{"de": "SI"}	{"de": "Slowenien"}	\N
a036d331-2abe-4ce4-b4f0-811bccc1bea4	SO	2020-10-29 13:33:19.755375	2020-10-29 13:33:19.756822	2020-10-29 13:33:19.756822	\N	f	\N	t	{"de": "SO"}	{"de": "Somalia"}	\N
48aa57e0-bbcd-494a-a987-e471dbb4e793	ES	2020-10-29 13:33:19.779702	2020-10-29 13:33:19.781228	2020-10-29 13:33:19.781228	\N	f	\N	t	{"de": "ES"}	{"de": "Spanien"}	\N
46cd8f27-364c-449d-8327-581d1d789692	LK	2020-10-29 13:33:19.798515	2020-10-29 13:33:19.799357	2020-10-29 13:33:19.799357	\N	f	\N	t	{"de": "LK"}	{"de": "Sri Lanka (ehem Ceylon)"}	\N
7e566493-faae-4321-88ac-3143a14b9261	SH	2020-10-29 13:33:19.820591	2020-10-29 13:33:19.821452	2020-10-29 13:33:19.821452	\N	f	\N	t	{"de": "SH"}	{"de": "St. Helena"}	\N
5ed528dc-f265-46b0-9807-dc8a5cf40a15	KN	2020-10-29 13:33:19.847171	2020-10-29 13:33:19.848456	2020-10-29 13:33:19.848456	\N	f	\N	t	{"de": "KN"}	{"de": "St. Kitts und Nevis (ehem St. Christopher und Nevis)"}	\N
da9c0415-cabc-406d-b47a-c553c62d3b95	LC	2020-10-29 13:33:19.871927	2020-10-29 13:33:19.873626	2020-10-29 13:33:19.873626	\N	f	\N	t	{"de": "LC"}	{"de": "St. Lucia"}	\N
592967e0-8e49-4609-af55-e9b38cbb7463	SM	2020-10-29 13:33:19.89818	2020-10-29 13:33:19.899759	2020-10-29 13:33:19.899759	\N	f	\N	t	{"de": "SM"}	{"de": "St. Marino"}	\N
923578c1-d1fa-44ed-949b-69c55eccf3a9	PM	2020-10-29 13:33:19.924749	2020-10-29 13:33:19.926273	2020-10-29 13:33:19.926273	\N	f	\N	t	{"de": "PM"}	{"de": "St. Pierre und Miquelon"}	\N
f921b59c-efa8-4328-8b0e-df7faf34907f	VC	2020-10-29 13:33:19.950729	2020-10-29 13:33:19.952317	2020-10-29 13:33:19.952317	\N	f	\N	t	{"de": "VC"}	{"de": "St. Vincent und die Grenadinen"}	\N
d52a7e95-c989-4da6-9e42-530b2a5f0d5a	ZA	2020-10-29 13:33:19.97785	2020-10-29 13:33:19.979202	2020-10-29 13:33:19.979202	\N	f	\N	t	{"de": "ZA"}	{"de": "Südafrika"}	\N
58833d5c-2a19-4259-b654-647db61c67a4	SD	2020-10-29 13:33:20.0008	2020-10-29 13:33:20.002336	2020-10-29 13:33:20.002336	\N	f	\N	t	{"de": "SD"}	{"de": "Sudan, Republik"}	\N
4c50516b-768f-4030-8eb3-61b255f73697	GS	2020-10-29 13:33:20.051052	2020-10-29 13:33:20.054702	2020-10-29 13:33:20.054702	\N	f	\N	t	{"de": "GS"}	{"de": "Südgeorgien und die Sandwichinseln"}	\N
8ad20b62-0fa9-4c3c-a066-2fd9359f1f84	SR	2020-10-29 13:33:20.100937	2020-10-29 13:33:20.102322	2020-10-29 13:33:20.102322	\N	f	\N	t	{"de": "SR"}	{"de": "Suriname"}	\N
092ed4a2-cf2b-426e-9f1a-97c173a4908b	SZ	2020-10-29 13:33:20.122122	2020-10-29 13:33:20.123303	2020-10-29 13:33:20.123303	\N	f	\N	t	{"de": "SZ"}	{"de": "Swasiland"}	\N
411503ca-5091-4a56-b5bb-f5433cba378f	SY	2020-10-29 13:33:20.143239	2020-10-29 13:33:20.144382	2020-10-29 13:33:20.144382	\N	f	\N	t	{"de": "SY"}	{"de": "Syrien, Arabische Republik"}	\N
3aaac8e8-805a-4b2c-9d5d-8b16a6dc90f5	TJ	2020-10-29 13:33:20.163611	2020-10-29 13:33:20.164754	2020-10-29 13:33:20.164754	\N	f	\N	t	{"de": "TJ"}	{"de": "Tadschikistan"}	\N
36657f2c-c1be-444a-98c1-173f476146c4	TZ	2020-10-29 13:33:20.183926	2020-10-29 13:33:20.185012	2020-10-29 13:33:20.185012	\N	f	\N	t	{"de": "TZ"}	{"de": "Tansania"}	\N
fd3108e7-7de8-4015-977b-8621efb130c2	TH	2020-10-29 13:33:20.204109	2020-10-29 13:33:20.205222	2020-10-29 13:33:20.205222	\N	f	\N	t	{"de": "TH"}	{"de": "Thailand"}	\N
28050ebb-9652-40c9-ba63-22feb33eb312	TG	2020-10-29 13:33:20.223591	2020-10-29 13:33:20.224602	2020-10-29 13:33:20.224602	\N	f	\N	t	{"de": "TG"}	{"de": "Togo"}	\N
cce2a66d-c5e6-4d03-9d5c-09d8dd1931fd	TK	2020-10-29 13:33:20.241601	2020-10-29 13:33:20.24251	2020-10-29 13:33:20.24251	\N	f	\N	t	{"de": "TK"}	{"de": "Tokelau"}	\N
e56e857b-6232-476a-a841-4bcbf64dc0f9	TO	2020-10-29 13:33:20.257169	2020-10-29 13:33:20.257905	2020-10-29 13:33:20.257905	\N	f	\N	t	{"de": "TO"}	{"de": "Tonga, Königreich"}	\N
8c33cfbc-9f74-4b2e-a924-38b53ccf8871	TT	2020-10-29 13:33:20.271999	2020-10-29 13:33:20.272729	2020-10-29 13:33:20.272729	\N	f	\N	t	{"de": "TT"}	{"de": "Trinidad und Tobago"}	\N
1dbc877c-2a7f-4d74-87f2-4847a578749e	TD	2020-10-29 13:33:20.286882	2020-10-29 13:33:20.287628	2020-10-29 13:33:20.287628	\N	f	\N	t	{"de": "TD"}	{"de": "Tschad"}	\N
00f0a783-1ae4-425c-b2a7-ee59a6f3ca9e	CZ	2020-10-29 13:33:20.301496	2020-10-29 13:33:20.302258	2020-10-29 13:33:20.302258	\N	f	\N	t	{"de": "CZ"}	{"de": "Tschechische Republik"}	\N
64f3ad7f-cb3f-4c4f-81ff-ce904daa128d	TN	2020-10-29 13:33:20.316961	2020-10-29 13:33:20.317851	2020-10-29 13:33:20.317851	\N	f	\N	t	{"de": "TN"}	{"de": "Tunesien"}	\N
e2aabc15-e462-47c6-b224-71f518d32d6c	TR	2020-10-29 13:33:20.333515	2020-10-29 13:33:20.334303	2020-10-29 13:33:20.334303	\N	f	\N	t	{"de": "TR"}	{"de": "Türkei"}	\N
ec6ec0f1-f63e-4d4e-b6cb-7960f2c5655f	TM	2020-10-29 13:33:20.353591	2020-10-29 13:33:20.354411	2020-10-29 13:33:20.354411	\N	f	\N	t	{"de": "TM"}	{"de": "Turkmenistan"}	\N
055b9518-5808-48f7-a6fd-3239fde1b2e5	TC	2020-10-29 13:33:20.372737	2020-10-29 13:33:20.373569	2020-10-29 13:33:20.373569	\N	f	\N	t	{"de": "TC"}	{"de": "Turks- und Caicosinseln"}	\N
ee0e7be3-fcb6-4c7d-b64c-84c5d206165d	TV	2020-10-29 13:33:20.391612	2020-10-29 13:33:20.392473	2020-10-29 13:33:20.392473	\N	f	\N	t	{"de": "TV"}	{"de": "Tuvalu"}	\N
519d58b5-042e-4999-9a41-85db6b493494	UG	2020-10-29 13:33:20.413283	2020-10-29 13:33:20.416961	2020-10-29 13:33:20.416961	\N	f	\N	t	{"de": "UG"}	{"de": "Uganda"}	\N
470bfd59-4b22-49af-90ec-fe7908acf37e	UA	2020-10-29 13:33:20.456105	2020-10-29 13:33:20.457399	2020-10-29 13:33:20.457399	\N	f	\N	t	{"de": "UA"}	{"de": "Ukraine"}	\N
f8f47a74-0b97-4964-81f5-34209144cca1	HU	2020-10-29 13:33:20.493524	2020-10-29 13:33:20.496306	2020-10-29 13:33:20.496306	\N	f	\N	t	{"de": "HU"}	{"de": "Ungarn"}	\N
e7b9270c-dd2e-4ec5-b39f-1472a1d93f7c	UY	2020-10-29 13:33:20.53175	2020-10-29 13:33:20.533533	2020-10-29 13:33:20.533533	\N	f	\N	t	{"de": "UY"}	{"de": "Uruguay"}	\N
e245267b-541a-4dfe-a35e-dc1a699d6133	UZ	2020-10-29 13:33:20.56982	2020-10-29 13:33:20.571327	2020-10-29 13:33:20.571327	\N	f	\N	t	{"de": "UZ"}	{"de": "Usbekistan"}	\N
6cab0f30-2a5d-494a-a6f1-43f3e26c727b	VU	2020-10-29 13:33:20.591835	2020-10-29 13:33:20.593016	2020-10-29 13:33:20.593016	\N	f	\N	t	{"de": "VU"}	{"de": "Vanuatu"}	\N
3b4b6771-67fb-4079-805e-7944cd2a799d	VA	2020-10-29 13:33:20.619362	2020-10-29 13:33:20.620314	2020-10-29 13:33:20.620314	\N	f	\N	t	{"de": "VA"}	{"de": "Vatikanstadt"}	\N
0f10635a-ac96-4905-b31d-b40449e70c7a	VE	2020-10-29 13:33:20.649277	2020-10-29 13:33:20.651359	2020-10-29 13:33:20.651359	\N	f	\N	t	{"de": "VE"}	{"de": "Venezuela"}	\N
7cfec776-57ee-434a-82c7-9bd1e0fd0842	AE	2020-10-29 13:33:20.672021	2020-10-29 13:33:20.672949	2020-10-29 13:33:20.672949	\N	f	\N	t	{"de": "AE"}	{"de": "Vereinigte Arabische Emirate"}	\N
a13ce5d4-3119-403b-b8ad-5009ef5cfd9c	US	2020-10-29 13:33:20.70094	2020-10-29 13:33:20.701836	2020-10-29 13:33:20.701836	\N	f	\N	t	{"de": "US"}	{"de": "Vereinigte Staaten von Amerika"}	\N
5fa93060-a05f-445e-8863-28cfb5599b68	GB	2020-10-29 13:33:20.716688	2020-10-29 13:33:20.717478	2020-10-29 13:33:20.717478	\N	f	\N	t	{"de": "GB"}	{"de": "Vereinigtes Königreich Großbritannien"}	\N
3ca481b6-4ab5-4b1c-92ec-24f782e01a3c	VN	2020-10-29 13:33:20.731165	2020-10-29 13:33:20.731877	2020-10-29 13:33:20.731877	\N	f	\N	t	{"de": "VN"}	{"de": "Vietnam"}	\N
ff86616d-91f1-4715-a25f-f6abb98214df	WF	2020-10-29 13:33:20.746017	2020-10-29 13:33:20.746868	2020-10-29 13:33:20.746868	\N	f	\N	t	{"de": "WF"}	{"de": "Wallis und Futuna"}	\N
573fa4f5-4100-483c-925d-8bd0c4519e78	CX	2020-10-29 13:33:20.762219	2020-10-29 13:33:20.76308	2020-10-29 13:33:20.76308	\N	f	\N	t	{"de": "CX"}	{"de": "Weihnachtsinseln"}	\N
c397a9f2-4983-403c-ad34-c29a93115b5a	BY	2020-10-29 13:33:20.814692	2020-10-29 13:33:20.818418	2020-10-29 13:33:20.818418	\N	f	\N	t	{"de": "BY"}	{"de": "Weißrußland (Belarus)"}	\N
4cd46fc1-b4a5-44bc-9a3b-4cf2eeea2a1d	CF	2020-10-29 13:33:20.850067	2020-10-29 13:33:20.851246	2020-10-29 13:33:20.851246	\N	f	\N	t	{"de": "CF"}	{"de": "Zentralafrikanische Republik"}	\N
c3bc8dbb-dd26-444a-8ef1-1af46cc74246	CY	2020-10-29 13:33:20.869552	2020-10-29 13:33:20.870537	2020-10-29 13:33:20.870537	\N	f	\N	t	{"de": "CY"}	{"de": "Zypern"}	\N
df831f44-fa0c-4066-9ce5-b44852a42122	EUR	2020-10-29 13:33:20.891959	2020-10-29 13:33:20.89303	2020-10-29 13:33:20.89303	\N	f	\N	t	{"de": "EUR"}	{"de": "Euro"}	\N
a82e3b86-206d-45fa-a964-f3a36edb8d12	USD	2020-10-29 13:33:20.910873	2020-10-29 13:33:20.911902	2020-10-29 13:33:20.911902	\N	f	\N	t	{"de": "USD"}	{"de": "US-Dollar"}	\N
0b37b573-dd6a-4da2-9101-528bc4e84b6f	HUF	2020-10-29 13:33:20.928676	2020-10-29 13:33:20.929552	2020-10-29 13:33:20.929552	\N	f	\N	t	{"de": "HUF"}	{"de": "Ungarische Forint"}	\N
f916e428-df94-484c-a913-cae8a1a0629a	CZK	2020-10-29 13:33:20.965511	2020-10-29 13:33:20.967113	2020-10-29 13:33:20.967113	\N	f	\N	t	{"de": "CZK"}	{"de": "Tschechische Kronen"}	\N
0d149210-4782-4d55-8d98-2050dcdf76f8	HRK	2020-10-29 13:33:20.986979	2020-10-29 13:33:20.988022	2020-10-29 13:33:20.988022	\N	f	\N	t	{"de": "HRK"}	{"de": "Kroatische Kuna"}	\N
4aa18e08-2c0d-4ba0-936a-04a6f966c9b1	CHF	2020-10-29 13:33:21.005666	2020-10-29 13:33:21.006756	2020-10-29 13:33:21.006756	\N	f	\N	t	{"de": "CHF"}	{"de": "Schweizer Franken"}	\N
bbf3d9f7-211a-48df-b808-d26e212e05e0	PLN	2020-10-29 13:33:21.030811	2020-10-29 13:33:21.031864	2020-10-29 13:33:21.031864	\N	f	\N	t	{"de": "PLN"}	{"de": "Polnische Złoty"}	\N
eb8b0e84-2578-41ca-b8f6-102e07403aac	DKK	2020-10-29 13:33:21.057393	2020-10-29 13:33:21.058444	2020-10-29 13:33:21.058444	\N	f	\N	t	{"de": "DKK"}	{"de": "Dänische Kronen"}	\N
42218a7a-1de6-4ca8-bdd1-1f7af2dfaeb4	Open Data	2020-10-29 13:33:21.080983	2020-10-29 13:33:21.082046	2020-10-29 13:33:21.082046	\N	f	\N	t	{"de": "Open Data"}	{}	\N
dc3649e5-2f11-41c9-91b7-502344cfbc87	Creative Commons	2020-10-29 13:33:21.102228	2020-10-29 13:33:21.10324	2020-10-29 13:33:21.10324	\N	f	\N	t	{"de": "Creative Commons"}	{}	\N
d9d390ce-16e5-403a-92cc-9a27619a1193	Public Domain Mark	2020-10-29 13:33:21.120814	2020-10-29 13:33:21.121972	2020-10-29 13:33:21.121972	\N	f	\N	t	{"de": "Public Domain Mark"}	{}	https://creativecommons.org/publicdomain/mark/1.0/
3ee7b7a9-0f6f-4d17-a8e9-16abe5298035	CC0	2020-10-29 13:33:21.144921	2020-10-29 13:33:21.146081	2020-10-29 13:33:21.146081	\N	f	\N	t	{"de": "CC0"}	{}	https://creativecommons.org/publicdomain/zero/1.0/
1418b03c-dead-48aa-895b-fdd63f125d16	CC BY	2020-10-29 13:33:21.164669	2020-10-29 13:33:21.165525	2020-10-29 13:33:21.165525	\N	f	\N	t	{"de": "CC BY"}	{}	\N
1560ae8a-2769-472c-9965-abb21d746780	CC BY 4.0	2020-10-29 13:33:21.180454	2020-10-29 13:33:21.181296	2020-10-29 13:33:21.181296	\N	f	\N	t	{"de": "CC BY 4.0"}	{}	https://creativecommons.org/licenses/by/4.0/
729cd792-5d08-4b7d-9706-07a546088a80	CC BY-SA	2020-10-29 13:33:21.197002	2020-10-29 13:33:21.197843	2020-10-29 13:33:21.197843	\N	f	\N	t	{"de": "CC BY-SA"}	{}	\N
aba7afb9-5f97-4d7b-8c8f-e9f9996ca170	CC BY-SA 4.0	2020-10-29 13:33:21.217182	2020-10-29 13:33:21.218028	2020-10-29 13:33:21.218028	\N	f	\N	t	{"de": "CC BY-SA 4.0"}	{}	https://creativecommons.org/licenses/by-sa/4.0/
2ed2785e-4022-405a-bdb3-aaaab91b59d7	CC BY-ND	2020-10-29 13:33:21.233305	2020-10-29 13:33:21.234182	2020-10-29 13:33:21.234182	\N	f	\N	t	{"de": "CC BY-ND"}	{}	\N
2f32f6c6-de5b-4651-a78e-04f293601fed	CC BY-ND 4.0	2020-10-29 13:33:21.249438	2020-10-29 13:33:21.25028	2020-10-29 13:33:21.25028	\N	f	\N	t	{"de": "CC BY-ND 4.0"}	{}	https://creativecommons.org/licenses/by-nd/4.0/
85525b77-0800-4e59-88e4-1d843e78bc6e	CC BY-NC	2020-10-29 13:33:21.265279	2020-10-29 13:33:21.266141	2020-10-29 13:33:21.266141	\N	f	\N	t	{"de": "CC BY-NC"}	{}	\N
6c6d98ab-66c1-45be-9fcb-caef7f7a21cf	CC BY-NC 4.0	2020-10-29 13:33:21.281291	2020-10-29 13:33:21.282141	2020-10-29 13:33:21.282141	\N	f	\N	t	{"de": "CC BY-NC 4.0"}	{}	https://creativecommons.org/licenses/by-nc/4.0/
b4021eec-e5a6-4598-8c97-f57e2d7ccbd7	CC BY-NC-SA	2020-10-29 13:33:21.297727	2020-10-29 13:33:21.298672	2020-10-29 13:33:21.298672	\N	f	\N	t	{"de": "CC BY-NC-SA"}	{}	\N
b8ea3f73-31b7-45f1-981b-0fa1c354791f	CC BY-NC-SA 4.0	2020-10-29 13:33:21.313554	2020-10-29 13:33:21.314351	2020-10-29 13:33:21.314351	\N	f	\N	t	{"de": "CC BY-NC-SA 4.0"}	{}	https://creativecommons.org/licenses/by-nc-sa/4.0/
3ee1339f-f944-462f-ae7b-f9ee1599dd41	CC BY-NC-ND	2020-10-29 13:33:21.342272	2020-10-29 13:33:21.346107	2020-10-29 13:33:21.346107	\N	f	\N	t	{"de": "CC BY-NC-ND"}	{}	\N
62b58faa-c7bd-4429-bf32-a937a8ac3bc9	CC BY-NC-ND 4.0	2020-10-29 13:33:21.373927	2020-10-29 13:33:21.375044	2020-10-29 13:33:21.375044	\N	f	\N	t	{"de": "CC BY-NC-ND 4.0"}	{}	https://creativecommons.org/licenses/by-nc-nd/4.0/
45920f24-f224-4014-9d90-6ebf5dfa9d8f	Sonstiges	2020-10-29 13:33:21.392411	2020-10-29 13:33:21.39335	2020-10-29 13:33:21.39335	\N	f	\N	t	{"de": "Sonstiges"}	{}	\N
30a28261-88ea-492d-a5b4-d2056070e2f4	Teilnahme Online	2020-10-29 13:33:21.436959	2020-10-29 13:33:21.438534	2020-10-29 13:33:21.438534	\N	f	\N	t	{"de": "Teilnahme Online"}	{}	https://pending.schema.org/OnlineEventAttendanceMode
eb1f94ad-59d9-46bd-a654-9a7a0b401b50	Teilnahme Offline	2020-10-29 13:33:21.459121	2020-10-29 13:33:21.460363	2020-10-29 13:33:21.460363	\N	f	\N	t	{"de": "Teilnahme Offline"}	{}	https://pending.schema.org/OfflineEventAttendanceMode
030173ab-82be-44ae-9a43-f398f32cf426	Gemischte Teilnahme	2020-10-29 13:33:21.480109	2020-10-29 13:33:21.48129	2020-10-29 13:33:21.48129	\N	f	\N	t	{"de": "Gemischte Teilnahme"}	{}	https://pending.schema.org/MixedEventAttendanceMode
6d6afa9c-6b21-4e3c-937c-742a5c345804	Veranstaltung abgesagt	2020-10-29 13:33:21.504932	2020-10-29 13:33:21.506056	2020-10-29 13:33:21.506056	\N	f	\N	t	{"de": "Veranstaltung abgesagt"}	{}	https://schema.org/EventCancelled
dbd46855-bf17-44f8-9d28-43c5f6bb4723	zu Online-Veranstaltung umgewandelt	2020-10-29 13:33:21.524937	2020-10-29 13:33:21.526099	2020-10-29 13:33:21.526099	\N	f	\N	t	{"de": "zu Online-Veranstaltung umgewandelt"}	{}	https://schema.org/EventMovedOnline
5e9e054a-6043-4b4b-8323-d2b7d3ad8d31	Veranstaltung auf unbekannten Zeitpunkt vertagt	2020-10-29 13:33:21.545116	2020-10-29 13:33:21.546258	2020-10-29 13:33:21.546258	\N	f	\N	t	{"de": "Veranstaltung auf unbekannten Zeitpunkt vertagt"}	{}	https://schema.org/EventPostponed
ba16cd9f-a2b1-443b-818a-e771cea9f2e0	Veranstaltung verschoben	2020-10-29 13:33:21.565151	2020-10-29 13:33:21.566295	2020-10-29 13:33:21.566295	\N	f	\N	t	{"de": "Veranstaltung verschoben"}	{}	https://schema.org/EventRescheduled
d76a6b42-c85e-4449-ae5d-c61e7e128856	Veranstaltung geplant	2020-10-29 13:33:21.585768	2020-10-29 13:33:21.586867	2020-10-29 13:33:21.586867	\N	f	\N	t	{"de": "Veranstaltung geplant"}	{}	https://schema.org/EventScheduled
5b5aa08d-27ec-45c1-9c2a-42b7cf40f3a5	Download	2020-10-29 13:33:21.611027	2020-10-29 13:33:21.612147	2020-10-29 13:33:21.612147	\N	f	\N	t	{"de": "Download"}	{}	https://schema.org/DownloadAction
4104b3d2-5e48-4678-bc36-5530de6081d8	externer Link	2020-10-29 13:33:21.631597	2020-10-29 13:33:21.632747	2020-10-29 13:33:21.632747	\N	f	\N	t	{"de": "externer Link"}	{}	https://schema.org/ViewAction
51268410-3a7e-4f84-a7b1-b78aa4c1c087	Bestellen	2020-10-29 13:33:21.672064	2020-10-29 13:33:21.674537	2020-10-29 13:33:21.674537	\N	f	\N	t	{"de": "Bestellen"}	{}	https://schema.org/OrderAction
630f7ea2-d57e-4d5b-87f4-3c816c51f73f	Eingestellt	2020-10-29 13:33:21.702198	2020-10-29 13:33:21.703357	2020-10-29 13:33:21.703357	\N	f	\N	t	{"de": "Eingestellt"}	{}	https://schema.org/Discontinued
9091211f-1547-42f5-b08c-f6d1688c2304	Verfügbar	2020-10-29 13:33:21.723322	2020-10-29 13:33:21.72448	2020-10-29 13:33:21.72448	\N	f	\N	t	{"de": "Verfügbar"}	{}	https://schema.org/InStock
d2114805-8b70-4899-86d9-92e27e551393	Nur im Geschäft	2020-10-29 13:33:21.744367	2020-10-29 13:33:21.74547	2020-10-29 13:33:21.74547	\N	f	\N	t	{"de": "Nur im Geschäft"}	{}	https://schema.org/InStoreOnly
32c4ee2f-b8bd-4ff9-8130-e962d5329028	Eingeschränkt verfügbar	2020-10-29 13:33:21.775257	2020-10-29 13:33:21.7789	2020-10-29 13:33:21.7789	\N	f	\N	t	{"de": "Eingeschränkt verfügbar"}	{}	https://schema.org/LimitedAvailability
85271509-7274-4825-bbd5-209af3918b39	Nur online	2020-10-29 13:33:21.814711	2020-10-29 13:33:21.817051	2020-10-29 13:33:21.817051	\N	f	\N	t	{"de": "Nur online"}	{}	https://schema.org/OnlineOnly
bc001262-28af-4e41-a4fb-666e7c04e908	Nicht vorrätig	2020-10-29 13:33:21.853025	2020-10-29 13:33:21.855161	2020-10-29 13:33:21.855161	\N	f	\N	t	{"de": "Nicht vorrätig"}	{}	https://schema.org/OutOfStock
2387d35a-5a36-4ca0-b19a-518417924374	Vorbestellen	2020-10-29 13:33:21.8784	2020-10-29 13:33:21.879639	2020-10-29 13:33:21.879639	\N	f	\N	t	{"de": "Vorbestellen"}	{}	https://schema.org/PreOrder
d8fe2025-31fa-4d8c-88db-890bc2fa79b9	Vorverkauf	2020-10-29 13:33:21.900725	2020-10-29 13:33:21.901921	2020-10-29 13:33:21.901921	\N	f	\N	t	{"de": "Vorverkauf"}	{}	https://schema.org/PreSale
a21fecd1-5c4d-41cd-869c-b0412ff7093b	Ausverkauft	2020-10-29 13:33:21.923175	2020-10-29 13:33:21.924413	2020-10-29 13:33:21.924413	\N	f	\N	t	{"de": "Ausverkauft"}	{}	https://schema.org/SoldOut
eb605ee8-2b82-4ed6-a440-7a48b168463c	Gebäck	2020-10-29 13:33:21.950397	2020-10-29 13:33:21.951731	2020-10-29 13:33:21.951731	\N	f	\N	t	{"de": "Gebäck"}	{}	\N
14ea1d8e-7b16-4a60-956c-5119da491179	Mehlspeise	2020-10-29 13:33:21.973494	2020-10-29 13:33:21.974792	2020-10-29 13:33:21.974792	\N	f	\N	t	{"de": "Mehlspeise"}	{}	\N
94aa1447-d880-45bf-b46c-0b65bcc9bd53	asiatisch	2020-10-29 13:33:21.996543	2020-10-29 13:33:21.997742	2020-10-29 13:33:21.997742	\N	f	\N	t	{"de": "asiatisch"}	{}	\N
e7a02bbe-e0b1-4a1e-96ce-fc5ee1422c9f	Vorspeise	2020-10-29 13:33:22.024921	2020-10-29 13:33:22.026225	2020-10-29 13:33:22.026225	\N	f	\N	t	{"de": "Vorspeise"}	{}	\N
c193fabb-749a-4a84-af8d-6a630ab82b89	freigegeben	2020-10-29 13:33:22.057526	2020-10-29 13:33:22.058502	2020-10-29 13:33:22.058502	\N	t	\N	t	{"de": "freigegeben"}	{}	\N
cc1ae4e7-33a7-4436-8c3f-5af7ea4e5d11	beim Partner	2020-10-29 13:33:22.090448	2020-10-29 13:33:22.092781	2020-10-29 13:33:22.092781	\N	t	\N	t	{"de": "beim Partner"}	{}	\N
0ee39c0b-91b7-4ac6-8a3a-8b34eacf77bd	in Review	2020-10-29 13:33:22.116863	2020-10-29 13:33:22.118178	2020-10-29 13:33:22.118178	\N	t	\N	t	{"de": "in Review"}	{}	\N
dda670af-ca8a-4268-b471-ede2241f6650	archiviert	2020-10-29 13:33:22.137558	2020-10-29 13:33:22.138655	2020-10-29 13:33:22.138655	\N	t	\N	t	{"de": "archiviert"}	{}	\N
ec023395-e306-43c5-9667-b93bbe09218a	nur Veranstaltungskalender	2020-10-29 13:33:22.162057	2020-10-29 13:33:22.163148	2020-10-29 13:33:22.163148	\N	t	\N	t	{"de": "nur Veranstaltungskalender"}	{}	\N
ee33caa5-2854-4d0b-90d0-213dece134d8	im Verkauf	2020-10-29 13:33:22.182439	2020-10-29 13:33:22.183575	2020-10-29 13:33:22.183575	\N	t	\N	t	{"de": "im Verkauf"}	{}	\N
f0413d70-2dc3-4470-86ca-c25f331d5c2f	online	2020-10-29 13:33:22.203156	2020-10-29 13:33:22.204285	2020-10-29 13:33:22.204285	\N	t	\N	t	{"de": "online"}	{}	\N
492c49c6-a13c-4466-a365-1ff74891f6e0	vorübergehend gestoppt	2020-10-29 13:33:22.223195	2020-10-29 13:33:22.224362	2020-10-29 13:33:22.224362	\N	t	\N	t	{"de": "vorübergehend gestoppt"}	{}	\N
b35d51cb-d5f8-4457-9e8f-6b2985c4df44	ausverkauft	2020-10-29 13:33:22.244149	2020-10-29 13:33:22.24528	2020-10-29 13:33:22.24528	\N	t	\N	t	{"de": "ausverkauft"}	{}	\N
77ccaa3d-39f8-4e13-aca0-f328497d39c4	Event wurde abgesagt	2020-10-29 13:33:22.263871	2020-10-29 13:33:22.265005	2020-10-29 13:33:22.265005	\N	t	\N	t	{"de": "Event wurde abgesagt"}	{}	\N
4d273888-ab7d-4bc8-8617-0c786d27d32c	Vorstellungsvariante vorhanden	2020-10-29 13:33:22.288609	2020-10-29 13:33:22.289781	2020-10-29 13:33:22.289781	\N	t	\N	t	{"de": "Vorstellungsvariante vorhanden"}	{}	\N
1d3f79df-78c5-41bc-a923-8f4ac0c34fb6	Preisübersteuerung/Preistabelle vorhanden	2020-10-29 13:33:22.309072	2020-10-29 13:33:22.310207	2020-10-29 13:33:22.310207	\N	t	\N	t	{"de": "Preisübersteuerung/Preistabelle vorhanden"}	{}	\N
3b9cbd67-3073-461b-984a-1711b5c6bc73	Frei für Wahlabo	2020-10-29 13:33:22.331768	2020-10-29 13:33:22.332906	2020-10-29 13:33:22.332906	\N	t	\N	t	{"de": "Frei für Wahlabo"}	{}	\N
4856be18-7fd2-4df9-b216-c5da68744c74	Personalisierung vorhanden	2020-10-29 13:33:22.361636	2020-10-29 13:33:22.365075	2020-10-29 13:33:22.365075	\N	t	\N	t	{"de": "Personalisierung vorhanden"}	{}	\N
e8f1f614-f8a4-43e7-a03a-07e278c0495c	Packetverwendung erforderlich	2020-10-29 13:33:22.389887	2020-10-29 13:33:22.391203	2020-10-29 13:33:22.391203	\N	t	\N	t	{"de": "Packetverwendung erforderlich"}	{}	\N
40f71bfc-e804-488e-b88b-3a7eaa493f54	Gehbehinderte	2020-10-29 13:33:22.418207	2020-10-29 13:33:22.419503	2020-10-29 13:33:22.419503	\N	t	\N	t	{"de": "Gehbehinderte"}	{}	\N
ca5c07df-275e-43ca-a3fa-0e6fe7b86ff0	barrierefrei	2020-10-29 13:33:22.44146	2020-10-29 13:33:22.442764	2020-10-29 13:33:22.442764	\N	t	\N	t	{"de": "barrierefrei"}	{}	\N
6be32111-1a17-487c-a043-e855fd8227a4	teilweise barrierefrei	2020-10-29 13:33:22.464384	2020-10-29 13:33:22.465575	2020-10-29 13:33:22.465575	\N	t	\N	t	{"de": "teilweise barrierefrei"}	{}	\N
478150c9-6e0c-4e43-9e29-ebcc3fbb0ed6	Rollstuhlfahrer	2020-10-29 13:33:22.487398	2020-10-29 13:33:22.488684	2020-10-29 13:33:22.488684	\N	t	\N	t	{"de": "Rollstuhlfahrer"}	{}	\N
4eaf933f-aac2-44d2-b6e3-227abb6be846	barrierefrei	2020-10-29 13:33:22.510937	2020-10-29 13:33:22.512273	2020-10-29 13:33:22.512273	\N	t	\N	t	{"de": "barrierefrei"}	{}	\N
10135158-e789-4ed7-9044-15edb8f27cab	teilweise barrierefrei	2020-10-29 13:33:22.531395	2020-10-29 13:33:22.532414	2020-10-29 13:33:22.532414	\N	t	\N	t	{"de": "teilweise barrierefrei"}	{}	\N
8d480b0f-2525-47fa-9f80-f91786908a3e	Hörbehinderte	2020-10-29 13:33:22.548362	2020-10-29 13:33:22.549245	2020-10-29 13:33:22.549245	\N	t	\N	t	{"de": "Hörbehinderte"}	{}	\N
5ac4d7f5-52fa-48a3-a693-9f0bc368dad6	barrierefrei	2020-10-29 13:33:22.572856	2020-10-29 13:33:22.574168	2020-10-29 13:33:22.574168	\N	t	\N	t	{"de": "barrierefrei"}	{}	\N
62f8a278-0779-46d2-8056-f2b11ceba2da	teilweise barrierefrei	2020-10-29 13:33:22.592131	2020-10-29 13:33:22.59314	2020-10-29 13:33:22.59314	\N	t	\N	t	{"de": "teilweise barrierefrei"}	{}	\N
b6437356-9b02-4499-8cea-bcf5b1b2234e	Gehörlose	2020-10-29 13:33:22.61077	2020-10-29 13:33:22.611803	2020-10-29 13:33:22.611803	\N	t	\N	t	{"de": "Gehörlose"}	{}	\N
5cc51c27-7afe-47d9-8892-d8e2847f32d7	barrierefrei	2020-10-29 13:33:22.629384	2020-10-29 13:33:22.630419	2020-10-29 13:33:22.630419	\N	t	\N	t	{"de": "barrierefrei"}	{}	\N
8730793f-18bf-42df-b53b-710f6472b5c7	teilweise barrierefrei	2020-10-29 13:33:22.648319	2020-10-29 13:33:22.649375	2020-10-29 13:33:22.649375	\N	t	\N	t	{"de": "teilweise barrierefrei"}	{}	\N
211a9552-6b8c-419d-8467-83db49e8ddc8	Sehbehinderte	2020-10-29 13:33:22.673395	2020-10-29 13:33:22.677288	2020-10-29 13:33:22.677288	\N	t	\N	t	{"de": "Sehbehinderte"}	{}	\N
0e22570b-b9af-4533-bd96-0e363679c945	barrierefrei	2020-10-29 13:33:22.712589	2020-10-29 13:33:22.714467	2020-10-29 13:33:22.714467	\N	t	\N	t	{"de": "barrierefrei"}	{}	\N
5d552dfa-f89a-4027-a363-f1b1d515b820	teilweise barrierefrei	2020-10-29 13:33:22.735264	2020-10-29 13:33:22.736303	2020-10-29 13:33:22.736303	\N	t	\N	t	{"de": "teilweise barrierefrei"}	{}	\N
e498dca6-bf17-44bc-9139-3ad5cfaca753	Blinde	2020-10-29 13:33:22.75548	2020-10-29 13:33:22.756671	2020-10-29 13:33:22.756671	\N	t	\N	t	{"de": "Blinde"}	{}	\N
9fd3b7f1-fb1c-4c27-acb0-1c328a6e0065	barrierefrei	2020-10-29 13:33:22.775886	2020-10-29 13:33:22.776952	2020-10-29 13:33:22.776952	\N	t	\N	t	{"de": "barrierefrei"}	{}	\N
7caf571d-90f5-4dfc-8410-11ecd36a46a0	teilweise barrierefrei	2020-10-29 13:33:22.796497	2020-10-29 13:33:22.797655	2020-10-29 13:33:22.797655	\N	t	\N	t	{"de": "teilweise barrierefrei"}	{}	\N
0d4f5511-0a1f-40ef-b7e3-dfaf611bfb66	Kognitiv Beeinträchtigte	2020-10-29 13:33:22.81995	2020-10-29 13:33:22.821212	2020-10-29 13:33:22.821212	\N	t	\N	t	{"de": "Kognitiv Beeinträchtigte"}	{}	\N
f9a415db-2068-4e75-8ef7-4d89f86e7a61	barrierefrei	2020-10-29 13:33:22.844203	2020-10-29 13:33:22.845328	2020-10-29 13:33:22.845328	\N	t	\N	t	{"de": "barrierefrei"}	{}	\N
0691a5a6-d5d8-4890-afc1-6c930f8de5b7	teilweise barrierefrei	2020-10-29 13:33:22.872916	2020-10-29 13:33:22.876681	2020-10-29 13:33:22.876681	\N	t	\N	t	{"de": "teilweise barrierefrei"}	{}	\N
00b3b85f-ae65-48c2-a5b9-713929f41251	Lift	2020-10-29 13:33:23.016942	2020-10-29 13:33:23.01788	2020-10-29 13:33:23.01788	\N	t	\N	t	{"de": "Lift"}	{}	\N
5e6cf422-1697-4fb7-9612-92e00cbc9c70	Örtlichkeit	2020-10-29 13:33:23.036388	2020-10-29 13:33:23.037368	2020-10-29 13:33:23.037368	\N	t	\N	t	{"de": "Örtlichkeit"}	{}	\N
22890874-16a4-4136-91bd-71e88a822d1c	Piste	2020-10-29 13:33:23.054659	2020-10-29 13:33:23.05562	2020-10-29 13:33:23.05562	\N	t	\N	t	{"de": "Piste"}	{}	\N
21ad2ac9-3441-47f5-bc42-90ea910ef3be	POI	2020-10-29 13:33:23.086603	2020-10-29 13:33:23.090101	2020-10-29 13:33:23.090101	\N	t	\N	t	{"de": "POI"}	{}	\N
2bd75a7e-dec8-41a5-af02-cf9f3ea17ed6	Tour	2020-10-29 13:33:23.134528	2020-10-29 13:33:23.136349	2020-10-29 13:33:23.136349	\N	t	\N	t	{"de": "Tour"}	{}	\N
b25af9fa-ebbc-4b57-980a-afe3458a2d54	Unterkunft	2020-10-29 13:33:23.161459	2020-10-29 13:33:23.162874	2020-10-29 13:33:23.162874	\N	t	\N	t	{"de": "Unterkunft"}	{}	\N
3d184ce1-87af-4c86-bec9-d88904d3d622	LocalBusiness	2020-10-29 13:33:23.184186	2020-10-29 13:33:23.185465	2020-10-29 13:33:23.185465	\N	t	\N	t	{"de": "LocalBusiness"}	{}	\N
4daaf11c-36e0-4339-ace8-f57f33cac27b	Gastronomischer Betrieb	2020-10-29 13:33:23.206318	2020-10-29 13:33:23.207575	2020-10-29 13:33:23.207575	\N	t	\N	t	{"de": "Gastronomischer Betrieb"}	{}	\N
4ac59333-587c-4d6b-b371-1e6472a1b6b5	Artikel	2020-10-29 13:33:23.250686	2020-10-29 13:33:23.251919	2020-10-29 13:33:23.251919	\N	t	\N	t	{"de": "Artikel"}	{}	\N
f5d68b40-ff74-4491-bd11-39f87aa1b6ae	Beschreibungstext	2020-10-29 13:33:23.27449	2020-10-29 13:33:23.275927	2020-10-29 13:33:23.275927	\N	t	\N	t	{"de": "Beschreibungstext"}	{}	\N
df0fedb2-e489-438f-8109-53f3e86e517d	Katalog	2020-10-29 13:33:23.299293	2020-10-29 13:33:23.300685	2020-10-29 13:33:23.300685	\N	t	\N	t	{"de": "Katalog"}	{}	\N
b1c80616-e5b2-42b1-b8ff-778904736860	Organisation	2020-10-29 13:33:23.324944	2020-10-29 13:33:23.326292	2020-10-29 13:33:23.326292	\N	t	\N	t	{"de": "Organisation"}	{}	\N
e4d48892-8970-41ca-adb0-ee988bd61bdd	Person	2020-10-29 13:33:23.34596	2020-10-29 13:33:23.346987	2020-10-29 13:33:23.346987	\N	t	\N	t	{"de": "Person"}	{}	\N
4f97ee10-706a-4c92-8160-c93cdd5815ce	Pauschalangebot	2020-10-29 13:33:23.364305	2020-10-29 13:33:23.365349	2020-10-29 13:33:23.365349	\N	t	\N	t	{"de": "Pauschalangebot"}	{}	\N
c38e4c8b-959d-4f7a-afa0-3c953f9169fa	Produkte	2020-10-29 13:33:23.381508	2020-10-29 13:33:23.382348	2020-10-29 13:33:23.382348	\N	t	\N	t	{"de": "Produkte"}	{}	\N
d2f18240-24ab-4ddd-8a74-49676ebfb5b3	Produkt	2020-10-29 13:33:23.398511	2020-10-29 13:33:23.399341	2020-10-29 13:33:23.399341	\N	t	\N	t	{"de": "Produkt"}	{}	\N
68bec3c2-26a1-4fb6-8782-5239f6345492	Produktgruppe	2020-10-29 13:33:23.415405	2020-10-29 13:33:23.416265	2020-10-29 13:33:23.416265	\N	t	\N	t	{"de": "Produktgruppe"}	{}	\N
56e0920e-8d04-47f1-93af-92b104f2bced	Produktmodel	2020-10-29 13:33:23.433428	2020-10-29 13:33:23.434357	2020-10-29 13:33:23.434357	\N	t	\N	t	{"de": "Produktmodel"}	{}	\N
4aafb623-dc12-413f-ab99-cc8df9c6af11	Service	2020-10-29 13:33:23.449925	2020-10-29 13:33:23.450809	2020-10-29 13:33:23.450809	\N	t	\N	t	{"de": "Service"}	{}	\N
e2281642-3bf1-4875-818c-f8686f3a385e	Veranstaltung	2020-10-29 13:33:23.466859	2020-10-29 13:33:23.467748	2020-10-29 13:33:23.467748	\N	t	\N	t	{"de": "Veranstaltung"}	{}	\N
de0b7f90-f189-431a-846c-941226971319	Veranstaltungsserie	2020-10-29 13:33:23.48389	2020-10-29 13:33:23.485106	2020-10-29 13:33:23.485106	\N	t	\N	t	{"de": "Veranstaltungsserie"}	{}	\N
07629667-4a5e-4dc1-a5e5-58a543912da8	Zimmer	2020-10-29 13:33:23.501377	2020-10-29 13:33:23.5023	2020-10-29 13:33:23.5023	\N	t	\N	t	{"de": "Zimmer"}	{}	\N
365b4c2a-dc17-45e8-a473-e197c4bdf8a0	Veranstaltungstermin	2020-10-29 13:33:23.518681	2020-10-29 13:33:23.519629	2020-10-29 13:33:23.519629	\N	t	\N	t	{"de": "Veranstaltungstermin"}	{}	\N
34ea96ba-e2d4-4e6a-ab4d-17f1d7845dff	Öffnungszeit	2020-10-29 13:33:23.535674	2020-10-29 13:33:23.53656	2020-10-29 13:33:23.53656	\N	t	\N	t	{"de": "Öffnungszeit"}	{}	\N
c32cfcb9-8d78-4602-b968-3f9befc6bba3	Öffnungszeit - Simple	2020-10-29 13:33:23.552992	2020-10-29 13:33:23.55392	2020-10-29 13:33:23.55392	\N	t	\N	t	{"de": "Öffnungszeit - Simple"}	{}	\N
5460f08b-ef15-4745-850d-bc645dcd7e0a	Öffnungszeit - Zeitspanne	2020-10-29 13:33:23.569491	2020-10-29 13:33:23.570386	2020-10-29 13:33:23.570386	\N	t	\N	t	{"de": "Öffnungszeit - Zeitspanne"}	{}	\N
f853e86a-5821-43c2-ae6b-f4c65b150cfc	Overlay	2020-10-29 13:33:23.586374	2020-10-29 13:33:23.587265	2020-10-29 13:33:23.587265	\N	t	\N	t	{"de": "Overlay"}	{}	\N
3cd0c226-c06a-4b6a-999b-7aa22328bb97	Publikations-Plan	2020-10-29 13:33:23.603374	2020-10-29 13:33:23.604277	2020-10-29 13:33:23.604277	\N	t	\N	t	{"de": "Publikations-Plan"}	{}	\N
602523c3-1b38-405f-af9d-5fa88a149a67	EventSchedule	2020-10-29 13:33:23.623891	2020-10-29 13:33:23.624805	2020-10-29 13:33:23.624805	\N	t	\N	t	{"de": "EventSchedule"}	{}	\N
9b18e490-806c-4ce5-b272-99f53c63f49f	Text	2020-10-29 13:33:23.661105	2020-10-29 13:33:23.22966	2020-10-29 13:33:23.664348	\N	t	\N	t	{"de": "Text"}	{}	\N
d96ea961-6bac-4a8d-9572-5fa5c2790a7a	Strukturierter Artikel	2020-10-29 13:33:23.692833	2020-10-29 13:33:23.693769	2020-10-29 13:33:23.693769	\N	t	\N	t	{"de": "Strukturierter Artikel"}	{}	\N
f2c72f4d-2de5-4387-8cbf-6e78558fb7e5	Rezept	2020-10-29 13:33:23.714304	2020-10-29 13:33:23.71554	2020-10-29 13:33:23.71554	\N	t	\N	t	{"de": "Rezept"}	{}	\N
c9058fb1-41a2-496c-888d-2e86226b3398	Inhaltsblock	2020-10-29 13:33:23.738915	2020-10-29 13:33:23.740137	2020-10-29 13:33:23.740137	\N	t	\N	t	{"de": "Inhaltsblock"}	{}	\N
e65ce639-3dd6-448a-8c0d-f9d1ec2ec76b	Rezeptkomponente	2020-10-29 13:33:23.765046	2020-10-29 13:33:23.766172	2020-10-29 13:33:23.766172	\N	t	\N	t	{"de": "Rezeptkomponente"}	{}	\N
39805c94-c85d-425b-b480-2701e1559c86	Zutat	2020-10-29 13:33:23.794978	2020-10-29 13:33:23.796209	2020-10-29 13:33:23.796209	\N	t	\N	t	{"de": "Zutat"}	{}	\N
5cd482ae-f03a-47d0-be49-0546142a54e5	Asset	2020-10-29 13:33:23.818094	2020-10-29 13:33:22.917639	2020-10-29 13:33:23.821083	\N	t	\N	t	{"de": "Asset"}	{}	\N
2d8eae91-effa-4774-8c9c-b1aa9dc882df	Audio	2020-10-29 13:33:23.835832	2020-10-29 13:33:23.836797	2020-10-29 13:33:23.836797	\N	t	\N	t	{"de": "Audio"}	{}	\N
eb67d4b7-8bb1-4101-806c-18f4f8f97fc4	Bild	2020-10-29 13:33:23.855345	2020-10-29 13:33:22.944056	2020-10-29 13:33:23.858004	\N	t	\N	t	{"de": "Bild"}	{}	\N
d02ae872-0768-4d0d-814f-90d3d131bef1	Video	2020-10-29 13:33:23.872529	2020-10-29 13:33:22.982058	2020-10-29 13:33:23.875014	\N	t	\N	t	{"de": "Video"}	{}	\N
f609f9eb-75d3-45af-9ba8-b56dabd1a10b	Datei	2020-10-29 13:33:23.887165	2020-10-29 13:33:23.887994	2020-10-29 13:33:23.887994	\N	t	\N	t	{"de": "Datei"}	{}	\N
7b6e38c6-941c-4933-afe7-89ad570e01b4	PDF	2020-10-29 13:33:23.905402	2020-10-29 13:33:23.906374	2020-10-29 13:33:23.906374	\N	t	\N	t	{"de": "PDF"}	{}	\N
103512a5-8595-4528-b859-210a5021d531	Ort	2020-10-29 13:33:23.927556	2020-10-29 13:33:23.000212	2020-10-29 13:33:23.930207	\N	t	\N	t	{"de": "Ort"}	{}	\N
c8dd8b95-c869-4d65-88a3-e7ec3a9f2082	Badeseen	2020-10-29 13:33:23.944668	2020-10-29 13:33:23.945706	2020-10-29 13:33:23.945706	\N	t	\N	t	{"de": "Badeseen"}	{}	\N
f53247bc-7cf1-41a2-b807-7255da660817	Skigebiet	2020-10-29 13:33:23.963353	2020-10-29 13:33:23.964261	2020-10-29 13:33:23.964261	\N	t	\N	t	{"de": "Skigebiet"}	{}	\N
e0d5e0c9-d0c7-43d2-8b70-0405dad45560	freie Scheehöhenmesspunkte	2020-10-29 13:33:23.981819	2020-10-29 13:33:23.982881	2020-10-29 13:33:23.982881	\N	t	\N	t	{"de": "freie Scheehöhenmesspunkte"}	{}	\N
53b49b78-0ce9-4cb2-b558-fd5a500a3453	Schneehöhe - Messpunkt	2020-10-29 13:33:24.001043	2020-10-29 13:33:24.002293	2020-10-29 13:33:24.002293	\N	t	\N	t	{"de": "Schneehöhe - Messpunkt"}	{}	\N
7f7d800f-3e53-424e-b85d-623fba723a30	Skigebiet - Addon	2020-10-29 13:33:24.022166	2020-10-29 13:33:24.023459	2020-10-29 13:33:24.023459	\N	t	\N	t	{"de": "Skigebiet - Addon"}	{}	\N
9b85459c-8d9a-46de-8812-658173d4b5d3	Job	2020-10-29 13:33:24.044336	2020-10-29 13:33:24.045552	2020-10-29 13:33:24.045552	\N	t	\N	t	{"de": "Job"}	{}	\N
20671dff-93fe-43d0-a53e-2e97426c418f	Zertifizierung	2020-10-29 13:33:24.065888	2020-10-29 13:33:24.066955	2020-10-29 13:33:24.066955	\N	t	\N	t	{"de": "Zertifizierung"}	{}	\N
c1bad241-8116-4243-aa5d-ed1e2b6488ac	Reisen für Alle	2020-10-29 13:33:24.08555	2020-10-29 13:33:24.086567	2020-10-29 13:33:24.086567	\N	t	\N	t	{"de": "Reisen für Alle"}	{}	\N
\.


--
-- TOC entry 4337 (class 0 OID 21623)
-- Dependencies: 226
-- Data for Name: classification_content_histories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classification_content_histories (id, content_data_history_id, classification_id, tag, classification, seen_at, created_at, updated_at, external_source_id, relation) FROM stdin;
5d6fb8cd-12b4-4ec8-af23-5b0466472b6d	ffb5ff24-f177-4f58-b5d2-9717cb1c8585	ab1d3fe9-ae29-466c-9a5f-d6af9f83ffbe	\N	\N	\N	2020-10-29 13:35:03.223824	2020-10-29 13:35:03.223824	\N	data_type
a6ac9940-084b-4971-91ae-8373baadbc48	60d94117-200e-4467-bb3e-8c40c20552d9	60c0dc66-33d7-4330-950c-d90162ec2d31	\N	\N	\N	2020-10-29 13:35:54.756532	2020-10-29 13:35:54.756532	\N	data_type
3a4e6b3e-0eed-48bb-a899-658b8c38b0a7	60d94117-200e-4467-bb3e-8c40c20552d9	560a57f4-0453-4cea-b407-d75e65f74f22	\N	\N	\N	2020-10-29 13:35:54.763851	2020-10-29 13:35:54.763851	\N	release_status_id
\.


--
-- TOC entry 4336 (class 0 OID 21614)
-- Dependencies: 225
-- Data for Name: classification_contents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classification_contents (id, content_data_id, classification_id, tag, classification, seen_at, created_at, updated_at, external_source_id, relation) FROM stdin;
b2239dae-47c7-4089-b316-84a70142066d	9ac37e86-80b6-413f-b8f0-d960ffee22d1	d7a8239f-f83d-4628-97ee-d727daf7d07b	\N	\N	\N	2020-10-29 13:34:36.078389	2020-10-29 13:34:36.078389	\N	data_type
ea275db8-ea44-4f4b-915b-86a616826d36	030312f0-c8c3-45da-bd65-0674b50aaddc	ab1d3fe9-ae29-466c-9a5f-d6af9f83ffbe	\N	\N	\N	2020-10-29 13:35:03.223824	2020-10-29 13:35:03.223824	\N	data_type
934367e0-9893-438b-a5e1-2554284f93de	48c72098-be3e-4779-977d-d9901ff4cbf9	60c0dc66-33d7-4330-950c-d90162ec2d31	\N	\N	\N	2020-10-29 13:35:54.756532	2020-10-29 13:35:54.756532	\N	data_type
9ff01e7b-f6ab-4b4e-81dc-57f371620c90	48c72098-be3e-4779-977d-d9901ff4cbf9	560a57f4-0453-4cea-b407-d75e65f74f22	\N	\N	\N	2020-10-29 13:35:54.763851	2020-10-29 13:35:54.763851	\N	release_status_id
\.


--
-- TOC entry 4322 (class 0 OID 21017)
-- Dependencies: 211
-- Data for Name: classification_groups; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classification_groups (id, classification_id, classification_alias_id, external_source_id, seen_at, created_at, updated_at, deleted_at) FROM stdin;
15bd4581-35cf-4ece-9ff4-19544ef1b0a0	2319914e-2a3c-45aa-bcdf-2d705a23dabc	bf248cd1-3c69-4afe-bad8-2c52018e351d	\N	2020-10-29 13:33:13.702159	2020-10-29 13:33:13.702677	2020-10-29 13:33:13.702677	\N
7c2330e8-1dd4-4fb5-acc0-d852882af04e	2ea159d5-3176-49b7-8e87-a3e640298382	111c75ee-b649-4512-8004-67b4558525f1	\N	2020-10-29 13:33:13.72083	2020-10-29 13:33:13.721247	2020-10-29 13:33:13.721247	\N
7834f9cb-7a1c-4143-a75e-a4b73889077f	c67575c7-91c4-426e-b97d-983e5bcc1d22	f57ed69a-a085-4c87-abfa-0c689eb2318c	\N	2020-10-29 13:33:13.743418	2020-10-29 13:33:13.743824	2020-10-29 13:33:13.743824	\N
0b3347e5-f42f-4bc5-b26c-422e5524082b	05737ee1-ee50-4fd2-bdca-17722eeaab09	4732d15d-1715-4336-aaa1-0a80806ca143	\N	2020-10-29 13:33:13.763868	2020-10-29 13:33:13.764366	2020-10-29 13:33:13.764366	\N
c8154fee-91b6-40fe-acda-254c4c2044c6	5980dc57-5701-4a9a-a584-77f95da8a76c	d0b32309-85e3-4dbb-b41a-e43da9a61f80	\N	2020-10-29 13:33:13.788456	2020-10-29 13:33:13.788898	2020-10-29 13:33:13.788898	\N
c2541ead-8336-4fb5-ae1b-c99b63d0702e	fb8791f0-2fdc-4374-aa4a-523b8246fd7e	762fac59-1292-4671-8b6c-876943fc493e	\N	2020-10-29 13:33:13.804895	2020-10-29 13:33:13.805329	2020-10-29 13:33:13.805329	\N
09b7e483-d118-40a1-a168-10d680bb260a	fcdcc46a-48db-4d75-bb5f-88cf1ab931dc	5e25de13-a296-4a6e-9fa0-ca34e437fe5f	\N	2020-10-29 13:33:13.827668	2020-10-29 13:33:13.828038	2020-10-29 13:33:13.828038	\N
df797f49-a3dd-4ce3-8e7e-599e0944c23d	acb322a9-f0f4-4dca-be13-c9a15fe1f102	628348b0-fae8-40b3-8732-a07e7590c047	\N	2020-10-29 13:33:13.8434	2020-10-29 13:33:13.843776	2020-10-29 13:33:13.843776	\N
75a7eb7f-5ad2-47f0-b5bb-23864dac09f1	3b1c24c6-7b9d-42ce-9959-957415d58c19	c375d854-ee78-45c0-b203-1e1252ebd94b	\N	2020-10-29 13:33:13.859115	2020-10-29 13:33:13.859517	2020-10-29 13:33:13.859517	\N
a482b23e-b558-4e94-9fcf-ae01250883a0	5831427c-d32c-4a46-abdb-46547e242d04	b5997502-9de0-413b-9e96-78986b212fff	\N	2020-10-29 13:33:13.887098	2020-10-29 13:33:13.887584	2020-10-29 13:33:13.887584	\N
6511aeab-5af2-463a-b3e6-dae12a91784a	9a4a5643-95db-406e-8f0f-b58cab33c6ac	23529ba4-1dc6-4cb1-bece-03e7a51633ef	\N	2020-10-29 13:33:13.909099	2020-10-29 13:33:13.909518	2020-10-29 13:33:13.909518	\N
46188d6d-fe82-4afb-8838-b2d09325e83b	d466bb3c-ab54-40f3-b9d0-12ab54244916	3ca4f33e-298e-4cbe-93c6-a10ec5d1ff0d	\N	2020-10-29 13:33:13.925598	2020-10-29 13:33:13.926036	2020-10-29 13:33:13.926036	\N
8581b5c0-512e-445a-8df9-c0b980b350dc	da1e13d5-e79e-43f5-a373-03b5d206178c	be8bcc75-6484-4c49-b081-8fd52100ea9c	\N	2020-10-29 13:33:13.941659	2020-10-29 13:33:13.942023	2020-10-29 13:33:13.942023	\N
162d9232-56b6-4aaf-b67a-19dabf757ad6	971795b0-e0cd-49a4-905a-479a09191e75	d5fc4daf-a6d6-405e-bc27-fe922c30a25c	\N	2020-10-29 13:33:13.958264	2020-10-29 13:33:13.95872	2020-10-29 13:33:13.95872	\N
5f15c857-d88c-4b52-bd32-65594020ec35	56d29600-e8b9-4849-84ae-e7a70b9c3dc7	1340b514-af44-4efa-b978-408efbfd3610	\N	2020-10-29 13:33:13.974979	2020-10-29 13:33:13.97542	2020-10-29 13:33:13.97542	\N
4a31b6ef-1596-4a92-9cb4-c36581fe18a2	53c15801-862e-4224-ab04-5c4fe195a7c8	3551d49b-003e-44ec-badf-081b733364d5	\N	2020-10-29 13:33:13.991219	2020-10-29 13:33:13.991625	2020-10-29 13:33:13.991625	\N
ddd730d4-3da5-41cd-ab47-0c7167c93b52	0d8d70a1-a263-4305-a5da-a0e62dd8e1bc	8bed8d93-d68d-486d-aaae-8a010e6f2686	\N	2020-10-29 13:33:14.007752	2020-10-29 13:33:14.008141	2020-10-29 13:33:14.008141	\N
21219450-0583-4b59-9e34-5a556c835699	9d8c9b55-d466-47ae-bfa2-08365fbe2628	b3ae1caf-092d-4a0b-992f-0ed423b8da1b	\N	2020-10-29 13:33:14.024019	2020-10-29 13:33:14.024406	2020-10-29 13:33:14.024406	\N
eba81639-5ec1-4646-b1bf-f63db76882e7	b8b2a8c1-70cb-4293-94d6-165b2ef6c2fb	13101455-5024-4443-a563-a3289706cdae	\N	2020-10-29 13:33:14.040046	2020-10-29 13:33:14.040518	2020-10-29 13:33:14.040518	\N
03c98281-4df7-445e-af75-418a3d0ba523	fd953f02-f98d-41fb-b9d5-0ccce9b7d1e0	d8325e1b-3fdb-4f06-a4b4-67abdd7dbf9f	\N	2020-10-29 13:33:14.056237	2020-10-29 13:33:14.056656	2020-10-29 13:33:14.056656	\N
d619672f-d9df-4c47-ae81-aac2b881423f	2d204544-f1a5-4e50-b6b7-878d794f4f12	13dde352-7056-4d0e-8291-f4585933756f	\N	2020-10-29 13:33:14.072549	2020-10-29 13:33:14.07297	2020-10-29 13:33:14.07297	\N
a5991511-1058-4fa1-bc1f-2f90347cf851	c839a756-ebb4-4c37-8de4-8236e0f74bf9	45da7461-120a-49f3-aec7-57312b081759	\N	2020-10-29 13:33:14.093039	2020-10-29 13:33:14.093469	2020-10-29 13:33:14.093469	\N
66a1f0ac-d307-482b-ad9e-8e27b47f6ae4	b3c40195-6b0f-48e6-b6cd-b41bfd667c06	a86c6cda-0577-4029-bcaf-5a6f1feaa0a3	\N	2020-10-29 13:33:14.116431	2020-10-29 13:33:14.116936	2020-10-29 13:33:14.116936	\N
32099c99-635c-470b-acf1-1e36f057e7aa	4bf2a820-fa37-42ec-985d-6931bd0bce3f	208ca653-ce4e-4be7-9a16-6da9d4ff765f	\N	2020-10-29 13:33:14.135976	2020-10-29 13:33:14.136379	2020-10-29 13:33:14.136379	\N
52c93491-b318-4fe4-bd13-569d45f391c8	334e052b-190e-47d7-8790-de872922fb36	e06e899d-b9d9-482a-891d-cdf9dfa25890	\N	2020-10-29 13:33:14.151837	2020-10-29 13:33:14.152224	2020-10-29 13:33:14.152224	\N
4c496640-18a0-4c5d-bb26-ad9e13996814	3399351d-f234-4db0-b3b5-19da4a8e6949	ad305e6d-fac7-40b2-924e-90842323d490	\N	2020-10-29 13:33:14.167549	2020-10-29 13:33:14.167887	2020-10-29 13:33:14.167887	\N
de6c352a-c894-4b01-acc0-8a2831c335b7	f1d5ea6a-526a-43f1-bb9e-25c076046bcd	337edf50-8286-4b20-a476-61afd0c2f289	\N	2020-10-29 13:33:14.193498	2020-10-29 13:33:14.19388	2020-10-29 13:33:14.19388	\N
1c5c14a4-e36b-4df3-a557-0c9cee34adfc	86ff7fd7-8eb9-45f8-b6eb-472507e08eea	b4da1cd0-9a32-46bd-9a3f-02e0594f1a54	\N	2020-10-29 13:33:14.209299	2020-10-29 13:33:14.209635	2020-10-29 13:33:14.209635	\N
1a56f0d7-359e-46e9-aaa5-6d42c58839b3	6f4ee8c8-d59b-4932-af71-6c4a32bdd818	3521a453-44ca-467c-9a43-ef823b615adf	\N	2020-10-29 13:33:14.225043	2020-10-29 13:33:14.225449	2020-10-29 13:33:14.225449	\N
646633ed-9e90-4968-a2a4-ea493028dc0f	9952c3bf-44eb-4044-a551-1e3c57d6087b	4d77cc72-7c10-4703-b91d-31bff579d365	\N	2020-10-29 13:33:14.240732	2020-10-29 13:33:14.241119	2020-10-29 13:33:14.241119	\N
1623d27c-c553-4432-ae1c-08f459170e06	3adc1955-ce5d-4d3f-a341-777e05b1a1af	5475057f-4592-412f-a79f-05e4857bdc94	\N	2020-10-29 13:33:14.256659	2020-10-29 13:33:14.257087	2020-10-29 13:33:14.257087	\N
4707ac38-249d-47d6-a208-5b3350056436	2c577c0b-04e7-4f9b-8f68-d6c47749cd05	3aab0cae-82d4-4491-b6a1-f179350458d5	\N	2020-10-29 13:33:14.272691	2020-10-29 13:33:14.273093	2020-10-29 13:33:14.273093	\N
bb9e093d-084d-4639-a390-372a29fad77f	0e82891a-c710-45ba-a330-ca3d4c43e33d	56c498d9-ccf8-4365-9838-6e2d3d940b17	\N	2020-10-29 13:33:14.289103	2020-10-29 13:33:14.289493	2020-10-29 13:33:14.289493	\N
0c620fab-ed46-4fff-9e3c-dc5cf28bbb42	b6c71400-758a-48c7-b22d-d07452da20ad	49e05b74-9608-45e0-8384-1ee28dc49151	\N	2020-10-29 13:33:14.305187	2020-10-29 13:33:14.305607	2020-10-29 13:33:14.305607	\N
196c657a-91ec-4892-8712-db4fe4021f99	4caad905-e9d8-4925-9b8a-996a9ebb0e97	fd540dff-9ff1-41cf-acaa-92cd09e4fb32	\N	2020-10-29 13:33:14.321132	2020-10-29 13:33:14.321523	2020-10-29 13:33:14.321523	\N
188c60e2-fe14-45c8-be6b-1ff451fe02a5	0785e13b-7455-4dc3-892d-10c9bd433e48	f81309a1-b16b-4c82-a5f4-4b7775ded168	\N	2020-10-29 13:33:14.337166	2020-10-29 13:33:14.337599	2020-10-29 13:33:14.337599	\N
b8f8d8bc-6f23-49ee-a6e6-f50d5ca160a1	ce9bac8b-3ba4-411b-a249-45403f7e3bb1	cb42ecd7-e873-447a-b297-9ef33feb6a61	\N	2020-10-29 13:33:14.353892	2020-10-29 13:33:14.354305	2020-10-29 13:33:14.354305	\N
b8a904e6-6742-4b72-a2fc-19b8cff7893d	e5ac3b70-6c13-45b0-93f4-77384ab89173	8d735758-5980-429e-a90c-6ad822383144	\N	2020-10-29 13:33:14.370077	2020-10-29 13:33:14.370492	2020-10-29 13:33:14.370492	\N
ab5aae57-87bf-41c1-93f3-4e5be6375378	bc60baea-dc29-4aa1-ba2b-f01f7ef561ce	9039c96f-6318-43bd-b69a-a73578124445	\N	2020-10-29 13:33:14.393431	2020-10-29 13:33:14.393824	2020-10-29 13:33:14.393824	\N
33075eb1-1ffa-4127-aee8-7442184f6989	7a82f233-9aed-4768-8165-4b76269e10e7	74117005-eb2b-462f-9bba-df4b6e29e885	\N	2020-10-29 13:33:14.40948	2020-10-29 13:33:14.409859	2020-10-29 13:33:14.409859	\N
7c4814ee-4ada-49e2-bfbb-7549c1285fc5	bcf89a04-dc43-40c7-8680-90e0becc504b	339779f9-5491-4fb9-97ad-48cefe8f542d	\N	2020-10-29 13:33:14.425287	2020-10-29 13:33:14.425679	2020-10-29 13:33:14.425679	\N
467b7f0a-bb30-4405-93b7-0b52c4c54a6d	c56ae8b9-3deb-4ac2-ae9e-13daa31a0172	eda40c83-7adb-43a0-a58b-19dd56e4e5d9	\N	2020-10-29 13:33:14.441514	2020-10-29 13:33:14.441843	2020-10-29 13:33:14.441843	\N
c21f7764-a9a7-4c67-9af1-471b89ab71b7	a269d142-2339-4636-b733-058848c0c811	5f7a33f1-2425-486b-861f-013d29eef6b3	\N	2020-10-29 13:33:14.457557	2020-10-29 13:33:14.457927	2020-10-29 13:33:14.457927	\N
1ea3b42d-8b12-4e92-b469-ffa83714faba	453f02a6-3dbf-4ac0-a8f1-61b24057a7d8	c5f42523-e73c-4526-aa6e-3f294130a91d	\N	2020-10-29 13:33:14.473214	2020-10-29 13:33:14.473606	2020-10-29 13:33:14.473606	\N
c0a79689-ccbf-40b5-acca-bb45dcc05d5e	9c4b0df9-d9d9-48d6-92ab-387d68e6b4f3	fb08e633-5656-49d8-8bf1-4ff9d8700e37	\N	2020-10-29 13:33:14.489415	2020-10-29 13:33:14.489777	2020-10-29 13:33:14.489777	\N
7109b315-97d0-4948-a9e2-0b3356d85575	74044c4e-6df8-419d-9532-4a5fed8310dd	01880fef-c961-4c1f-b0cb-38f18e1f20c1	\N	2020-10-29 13:33:14.505408	2020-10-29 13:33:14.50583	2020-10-29 13:33:14.50583	\N
293869dd-c846-40c8-b82a-81da407c497d	d3c4c166-18f3-45c8-9ffe-cef16a3ddd66	5fb915ca-6557-4c8b-a87b-bd5aeb33ae1a	\N	2020-10-29 13:33:14.522078	2020-10-29 13:33:14.522518	2020-10-29 13:33:14.522518	\N
b2581ae8-46e3-4602-a02d-448a8f07eb63	a58d8d9c-d114-47ec-997e-c48b2bb7791d	59434602-a0c4-43f9-ab32-3b4278c61acd	\N	2020-10-29 13:33:14.538103	2020-10-29 13:33:14.538499	2020-10-29 13:33:14.538499	\N
3f74dc3c-1772-4287-975b-7c375167b6b7	3f1e1acb-835e-4d34-8e74-2e6b4e788a4c	f3cef5c9-82e6-450d-a628-dc4d84d9e9b4	\N	2020-10-29 13:33:14.5539	2020-10-29 13:33:14.554292	2020-10-29 13:33:14.554292	\N
c6f9c67f-f6e5-4ba1-b5cf-69228c0cafa4	a4c8bd0a-d375-4b4a-844a-afe278e9ee44	f017d4b5-5201-4824-832b-0124b2089aec	\N	2020-10-29 13:33:14.569713	2020-10-29 13:33:14.570068	2020-10-29 13:33:14.570068	\N
da16b3c0-b420-4e33-8aa0-10dba8ad5348	8d8bd95f-960e-48ef-a26e-264f4600f20f	0930b05d-907b-466a-88a9-06fb00666d80	\N	2020-10-29 13:33:14.585374	2020-10-29 13:33:14.585765	2020-10-29 13:33:14.585765	\N
a6eb9698-ab8c-43a1-b95b-640174045e67	250d7dfd-d4a0-49c2-9cc1-e2cdfa604c87	4095f332-2180-4dd9-a187-d19275328392	\N	2020-10-29 13:33:14.600857	2020-10-29 13:33:14.601223	2020-10-29 13:33:14.601223	\N
fba23e79-bd9f-40a5-9b71-b55e2f792d6c	eb3de79a-d02e-4e48-9b6c-b8e176ad63da	bdf50908-b8e2-4bdc-bca5-ddffab01d3af	\N	2020-10-29 13:33:14.616544	2020-10-29 13:33:14.61692	2020-10-29 13:33:14.61692	\N
7fee392b-d57c-482a-a522-70d8b665fd11	dd9bfc58-8e25-4399-8916-2a93f141a9ef	8f62644e-ffdd-48da-a8ea-14393f146440	\N	2020-10-29 13:33:14.632373	2020-10-29 13:33:14.632772	2020-10-29 13:33:14.632772	\N
cccd3415-a027-449d-bd98-2e46cdc0ee24	3ab2371e-1d6f-450c-9325-5ccde4f7e174	82e65628-d1cc-45fe-a839-5ed265a8825a	\N	2020-10-29 13:33:14.655917	2020-10-29 13:33:14.656308	2020-10-29 13:33:14.656308	\N
ff4bf6aa-f215-49b8-8998-ef9f9a549f83	98f1e426-8148-4ada-a786-3f227b4dbb21	161ae833-f72a-44f3-b1e5-70ca30889e4c	\N	2020-10-29 13:33:14.672349	2020-10-29 13:33:14.672742	2020-10-29 13:33:14.672742	\N
54be404c-6dfb-4276-8bde-d4caeceed53e	0b212ccb-9524-4296-8160-61a01c1de449	841ad96c-2876-42b2-b96a-74d4fc054a84	\N	2020-10-29 13:33:14.688352	2020-10-29 13:33:14.688773	2020-10-29 13:33:14.688773	\N
6030a782-0a6f-4a9d-8830-30a5e89ff1e5	64bdc356-42f0-4d7c-9038-cc34f4a76124	57845206-2937-43ae-8e65-c9baecd9a251	\N	2020-10-29 13:33:14.726915	2020-10-29 13:33:14.727318	2020-10-29 13:33:14.727318	\N
7cd3613b-6edd-47fb-842e-a2268a4627b1	c943e9f8-d342-439f-b2fc-0cf311ad8cc8	0e75411d-5018-4390-8a9b-b0635fc7952a	\N	2020-10-29 13:33:14.744149	2020-10-29 13:33:14.744609	2020-10-29 13:33:14.744609	\N
45a7fd3a-f932-4c65-b548-40a0b06e1333	4ccfb52b-a8f5-4e06-98a2-bd5288109cd9	bbeb21f7-3107-4be8-ad2f-8d149d60cc7f	\N	2020-10-29 13:33:14.761586	2020-10-29 13:33:14.762057	2020-10-29 13:33:14.762057	\N
30800cdf-2fcf-408f-927a-20243adf6687	b9bc7a46-bbd7-42ab-8b36-e090d332035e	2537adce-6e9b-49b1-9b27-9664fc5f8050	\N	2020-10-29 13:33:14.785838	2020-10-29 13:33:14.786318	2020-10-29 13:33:14.786318	\N
58850a9e-6e81-4c1a-8fb0-068ba8eeda84	382699cf-963e-4c4b-b7ed-501ce0161788	e9706e76-3e86-4ca3-8ff8-695dc89e601d	\N	2020-10-29 13:33:14.803809	2020-10-29 13:33:14.804291	2020-10-29 13:33:14.804291	\N
630ff3ff-458c-4caf-b29c-bfeec30022d8	525d643e-3b56-4ea1-9d18-c87b35a9cecf	679f1ab9-6628-46e4-b4f6-5cd969067936	\N	2020-10-29 13:33:14.821567	2020-10-29 13:33:14.822008	2020-10-29 13:33:14.822008	\N
cefbc45d-6124-4e68-80d0-1b8ba4ee1ead	ac08fc85-f0e4-415e-a03f-525f6333611d	30185785-1ef5-49c2-865f-a17eb7d62269	\N	2020-10-29 13:33:14.85985	2020-10-29 13:33:14.861046	2020-10-29 13:33:14.861046	\N
d7087abf-2260-49ed-a21a-101555bcd6f8	b1260eca-e131-460f-8b07-c51e5d1f7360	7ddcab5e-9a31-45c9-bd79-a4aca4fe6372	\N	2020-10-29 13:33:14.89039	2020-10-29 13:33:14.892442	2020-10-29 13:33:14.892442	\N
39161a72-c153-4baf-87f0-6e68c138c74b	a3226808-3834-4701-818c-7089af89d41c	f36964e7-bf20-4915-86a7-2f02d5958b0c	\N	2020-10-29 13:33:14.91866	2020-10-29 13:33:14.919454	2020-10-29 13:33:14.919454	\N
07dac225-1a6f-4fae-8358-4dfe837bd8ea	42908ee8-e23c-403c-bea9-828b5f1ec831	c34e9323-a2b9-406d-b7ff-602d6eab7c4e	\N	2020-10-29 13:33:14.955824	2020-10-29 13:33:14.956477	2020-10-29 13:33:14.956477	\N
52cfc65d-32e2-4a57-bfa8-c42b38d78d6d	a4912fac-b99d-41f5-a48b-3acf7952ea01	bf9ccf9a-cd41-4964-a4e4-f0b87981b605	\N	2020-10-29 13:33:14.998923	2020-10-29 13:33:14.999359	2020-10-29 13:33:14.999359	\N
192033d8-861f-4c76-b64a-93bcf326278d	7b3dc3d0-f7b0-420a-abdb-a60457c10645	f8af7274-f0df-493d-b286-c120672a2cf2	\N	2020-10-29 13:33:15.020291	2020-10-29 13:33:15.020713	2020-10-29 13:33:15.020713	\N
281b0459-9752-45fd-87f2-5647284416ad	411651a1-3e39-4229-b043-b5a3c779384d	ebbe1b3c-1f60-4b55-b00e-b5f82eb52b85	\N	2020-10-29 13:33:15.036873	2020-10-29 13:33:15.037258	2020-10-29 13:33:15.037258	\N
b5b70251-7e32-434e-a7d7-dfc04efe2521	8f57729a-4bb9-43e7-8a7d-41f93aad0f83	6e4afbda-3db4-4767-82f3-d73d75bf897c	\N	2020-10-29 13:33:15.05804	2020-10-29 13:33:15.058438	2020-10-29 13:33:15.058438	\N
1030864e-34ca-4f84-9bb4-d57ea6e82d4a	4f4e4790-58bf-4ee9-a831-6d3e4f606e52	f4244058-b6ac-499e-aa66-c1643475234a	\N	2020-10-29 13:33:15.075018	2020-10-29 13:33:15.075417	2020-10-29 13:33:15.075417	\N
016f6aa9-55f4-4d07-8e4a-3af0a0605c6d	a47be155-5cc7-4a14-aef6-15254cd66c45	f4d0ca61-e879-4364-9335-c03b9ca9329a	\N	2020-10-29 13:33:15.097004	2020-10-29 13:33:15.097478	2020-10-29 13:33:15.097478	\N
4907c0b0-8eb9-4ffd-98cd-2aa9c229a61f	a6f9503f-c6e4-4487-92d2-4aaf6f996720	b248d1ee-1f1d-4a34-8927-3425482c82f7	\N	2020-10-29 13:33:15.118862	2020-10-29 13:33:15.119303	2020-10-29 13:33:15.119303	\N
5d679b71-9c24-46c2-bb82-6825be9d8d75	9d7cb346-b77b-49b0-84df-5710eb79c3de	1982cb17-3eb9-4a08-91d8-f4f857533a3f	\N	2020-10-29 13:33:15.135776	2020-10-29 13:33:15.13618	2020-10-29 13:33:15.13618	\N
88db46ae-fa40-415c-b2c1-4e82e7fd7eeb	c35800f5-a15a-4d42-8faa-1f654bf36889	2a6af101-a35c-481d-9d76-21e363c31596	\N	2020-10-29 13:33:15.152643	2020-10-29 13:33:15.153042	2020-10-29 13:33:15.153042	\N
1724fb52-13b4-4974-b3fb-71e3eb50bf6b	82ded662-bc46-43bb-80d0-6e9a539ece86	747e0362-b3f5-4d8e-b1c0-888e7e217dc5	\N	2020-10-29 13:33:15.169238	2020-10-29 13:33:15.169633	2020-10-29 13:33:15.169633	\N
20f0a634-a6ef-4bbe-80e8-8334b4221d13	ddb17ae8-387f-4990-ab83-b88150b2bdb6	98f28440-8090-48ac-9e1a-056720370fcb	\N	2020-10-29 13:33:15.185962	2020-10-29 13:33:15.186413	2020-10-29 13:33:15.186413	\N
8e979124-9002-49c7-abfb-40da53435eba	cda9e956-eac6-46cc-ab91-4ae953da54a2	b94e424b-8e82-4ecf-a256-99490b542d56	\N	2020-10-29 13:33:15.203113	2020-10-29 13:33:15.203598	2020-10-29 13:33:15.203598	\N
a6638b81-f57b-42d2-8182-76fa4efd0a13	c6c56c3a-df25-4062-b71b-b4744b3a39f7	2c921f29-3bca-4577-9eae-c6e0bc4c3a2a	\N	2020-10-29 13:33:15.224665	2020-10-29 13:33:15.225069	2020-10-29 13:33:15.225069	\N
6350f21d-3d10-44d1-b2a7-c18ca2097b03	cf42f40d-1f84-4d6f-93c0-ab6ed8a4beb1	f83ae840-230f-4e7b-8c15-0b8d0453ef70	\N	2020-10-29 13:33:15.244756	2020-10-29 13:33:15.245172	2020-10-29 13:33:15.245172	\N
1804cb10-7452-4ceb-9fb6-10ca493aca1a	85b3f8a3-95a2-40ae-9ab4-38b5e8ac3c84	afe80ac4-d82d-492a-b59c-d0f8a543bcba	\N	2020-10-29 13:33:15.261584	2020-10-29 13:33:15.262059	2020-10-29 13:33:15.262059	\N
d4789e08-f1ea-47a2-9f57-4c78e047d566	8ba65e4f-f382-4d38-9d04-dbacc3857847	85324b6b-0d1c-4642-907e-b3bb0346e39c	\N	2020-10-29 13:33:15.278986	2020-10-29 13:33:15.279401	2020-10-29 13:33:15.279401	\N
cf2047a2-2342-4cf4-a235-cad291014b1e	f07b3691-4fbc-4b41-9f85-af1f80c0bfdf	cf35cec9-5560-4732-a532-45783007bbc3	\N	2020-10-29 13:33:15.295923	2020-10-29 13:33:15.296378	2020-10-29 13:33:15.296378	\N
93b95c1e-6d74-4ad3-abf2-6417a638cd15	514da42f-bc3a-43c9-9e5b-7d1ad48127fb	da527921-ee5f-42d3-9d6e-c149d86b3e67	\N	2020-10-29 13:33:15.312861	2020-10-29 13:33:15.313253	2020-10-29 13:33:15.313253	\N
73724df3-a94f-4ab9-a520-a0f3c00b87fb	be372422-ee0e-4447-ad28-7ead7d2bcde5	302d20af-9b6d-401a-8715-8a79b9a1c53f	\N	2020-10-29 13:33:15.33651	2020-10-29 13:33:15.337002	2020-10-29 13:33:15.337002	\N
8c5cf381-0280-4415-8352-5e56ba05dfd6	729b6513-d6e7-4ac5-beb4-6f04b06431a3	996295b3-cbdb-4012-ad6d-c30c445f040a	\N	2020-10-29 13:33:15.353856	2020-10-29 13:33:15.354289	2020-10-29 13:33:15.354289	\N
dfab10f6-f37a-4d00-8b9f-beba7e0cce15	42824017-ceaa-4337-9a33-9e39457bf76b	5b709e4a-9729-433e-84e7-d34fd380a70d	\N	2020-10-29 13:33:15.371239	2020-10-29 13:33:15.37172	2020-10-29 13:33:15.37172	\N
f15612a2-60a7-4563-8af5-59d7158deb19	db4fca96-2e1e-4b8b-a2c7-96d3931abe64	3f6a502d-68a2-42f9-a193-dffe535114d7	\N	2020-10-29 13:33:15.388396	2020-10-29 13:33:15.388842	2020-10-29 13:33:15.388842	\N
df0a7248-68bc-478c-a0e7-b076df95c537	43443479-d28b-41c1-9851-f5fb5157a6ac	fd9f5a14-6a1e-410a-b2e6-75ea771b0825	\N	2020-10-29 13:33:15.409721	2020-10-29 13:33:15.410188	2020-10-29 13:33:15.410188	\N
6d7c6ed5-b36d-410c-98c9-f3d639d2d6a4	4d8bca72-e829-4193-a217-d8bdce746e44	51ee5fa7-690a-44ba-a2d3-3fafa74214c1	\N	2020-10-29 13:33:15.427495	2020-10-29 13:33:15.42803	2020-10-29 13:33:15.42803	\N
8e562e8d-a77a-4c38-bd9a-a59f9fd25548	28891271-1dbe-4983-8ae0-d2b02a6fd50f	91cc62df-9f3e-4154-9e58-9aa4c0e2ff11	\N	2020-10-29 13:33:15.448792	2020-10-29 13:33:15.449273	2020-10-29 13:33:15.449273	\N
9c8d4844-cd1e-4ae8-a51a-f2479d4f1535	d363ad8f-d522-43c6-b739-9a0df1668a71	30514366-e9a8-4e4d-94b0-35b8901e6159	\N	2020-10-29 13:33:15.468494	2020-10-29 13:33:15.468894	2020-10-29 13:33:15.468894	\N
83b6f181-b97b-4d52-87d1-d6ded4ed1ab6	e2af3d12-3559-4962-bec9-bc6dcb6d6638	951f128d-29ac-4189-81f5-8b6ab66fcf2e	\N	2020-10-29 13:33:15.487578	2020-10-29 13:33:15.488129	2020-10-29 13:33:15.488129	\N
6d74d669-fe74-4aff-9223-4fc16f8cb8b3	b3a09db9-0f8d-4d61-a715-a70ed7e5b155	30a03a04-5685-47a4-a9b0-8e981f5e2e18	\N	2020-10-29 13:33:15.507453	2020-10-29 13:33:15.507911	2020-10-29 13:33:15.507911	\N
6b0cab6b-d5dc-4b1a-95bc-63a63c11bc49	42aac85c-3d89-4c01-a22e-5eb2b0b443bf	445f838c-0e04-43c4-aa15-5f8e38c0a2b7	\N	2020-10-29 13:33:15.524763	2020-10-29 13:33:15.525205	2020-10-29 13:33:15.525205	\N
57eb388c-36f8-4451-97ef-ecb94c43875f	81c7a1b6-597b-4d5e-9746-514fdea9d35e	76617b76-ffc2-43a9-a58b-463684da3f27	\N	2020-10-29 13:33:15.546015	2020-10-29 13:33:15.546478	2020-10-29 13:33:15.546478	\N
ef1e6bc4-7c63-434d-a669-538c5e35e462	7a4aaaf9-8949-49aa-91b6-dd1e4b7493e9	fdae0a60-ce08-4b75-87df-cde67ea958de	\N	2020-10-29 13:33:15.563163	2020-10-29 13:33:15.563615	2020-10-29 13:33:15.563615	\N
74974e29-43f2-4e71-9ce0-026ffa0e31d5	aaabe993-e798-4fdc-b8a3-645f96a412a4	a4a9cf39-3944-4e9c-a0d0-55aea7939b56	\N	2020-10-29 13:33:15.58009	2020-10-29 13:33:15.580503	2020-10-29 13:33:15.580503	\N
cab82506-7f98-482b-beed-25c9ee4898a9	2e278c8c-4b1b-4324-8148-d17ae9e69d69	23ab564e-0a95-4ca3-afd9-4389ce0ff210	\N	2020-10-29 13:33:15.597639	2020-10-29 13:33:15.598068	2020-10-29 13:33:15.598068	\N
357dc7b2-e0bc-4abe-a5f5-9f609d2eee3e	922f506c-182e-4846-9b11-c413fa86af06	06191f9b-89cf-4a62-8754-5dd52a3665ed	\N	2020-10-29 13:33:15.615553	2020-10-29 13:33:15.615964	2020-10-29 13:33:15.615964	\N
4acdbd20-42e2-4deb-b1e2-96549c84f615	e35c545e-45ef-4a0d-9922-67865edda02b	4f9d3ef9-3522-424e-b959-99b523b6c420	\N	2020-10-29 13:33:15.633439	2020-10-29 13:33:15.633934	2020-10-29 13:33:15.633934	\N
d936ceaa-01a7-4114-94ee-f2efa99abf6d	bb4b3f4d-0ded-46e0-abbb-56053a2c75e9	fea54fd7-e4a0-4df2-a6c2-6c43ecc4a37b	\N	2020-10-29 13:33:15.65662	2020-10-29 13:33:15.657108	2020-10-29 13:33:15.657108	\N
1023cf67-6d40-48e3-b0ea-c357ee1e7172	44e460e3-77c0-4458-bb19-5e934181b50a	a3374280-2d1d-4361-8046-5adbcc018636	\N	2020-10-29 13:33:15.674538	2020-10-29 13:33:15.674989	2020-10-29 13:33:15.674989	\N
7f7d491c-ea83-4589-8c36-4f28ae064cb1	9e97859d-f6af-45eb-86a9-e420c100f873	a532984d-e360-46a6-a393-7e027342fba0	\N	2020-10-29 13:33:15.692226	2020-10-29 13:33:15.692652	2020-10-29 13:33:15.692652	\N
3be9ac1e-9d41-4e28-bc15-e752b467bcc0	d41300b2-9245-4f63-bc26-ddc972afec4b	561a1d5c-7e3d-4219-bb78-8292abeb0b68	\N	2020-10-29 13:33:15.70998	2020-10-29 13:33:15.710385	2020-10-29 13:33:15.710385	\N
29289765-9557-4d6d-b757-698cf7da5c7a	7498a2c5-937f-41fb-b3f0-c8519b0931dd	a94f41a7-5402-4647-a1f9-b39bb4abe148	\N	2020-10-29 13:33:15.727719	2020-10-29 13:33:15.728163	2020-10-29 13:33:15.728163	\N
7d4367b9-55b0-417e-afed-7bedd8770978	20fb07d1-4225-4216-b4b8-7f7c5c9438eb	87667340-ffe7-4aa9-87f9-a8108befadbc	\N	2020-10-29 13:33:15.744868	2020-10-29 13:33:15.745309	2020-10-29 13:33:15.745309	\N
2a01a298-c8d1-4395-912f-cc2c1782f211	7b8642eb-5787-4979-97be-fd2a1e5ed904	9bc87ce7-8214-46d8-842c-ee471b13bf81	\N	2020-10-29 13:33:15.766834	2020-10-29 13:33:15.767352	2020-10-29 13:33:15.767352	\N
56d48906-c929-42e5-a2ad-bccebaa33abc	47117b23-8af6-4bd5-9bf1-14954602930f	9a5b561b-eef0-481b-8bd5-8324b404c976	\N	2020-10-29 13:33:15.785279	2020-10-29 13:33:15.785729	2020-10-29 13:33:15.785729	\N
ca232e7a-2f4b-4767-9892-dc84eea4e61b	e145efd3-4ddb-4ea0-b381-70145bfa38c4	342e674b-b990-4822-b95a-2b12c629aadb	\N	2020-10-29 13:33:15.803836	2020-10-29 13:33:15.804362	2020-10-29 13:33:15.804362	\N
8f9c86ae-7533-43fa-9419-d065b649b6a5	89a54aab-002e-4057-93a5-01defa05f8df	82900adc-3257-48ab-a6b1-b5493e34ce3a	\N	2020-10-29 13:33:15.82418	2020-10-29 13:33:15.825852	2020-10-29 13:33:15.825852	\N
0ffd971d-6088-4731-8c48-69d6eef45854	3c5f6297-f693-496d-adca-d4cc71680294	0b29236c-4548-4ef3-8be8-4c00858a9fc3	\N	2020-10-29 13:33:15.863254	2020-10-29 13:33:15.86453	2020-10-29 13:33:15.86453	\N
d93af105-0bbd-4444-b43e-1639bb6fcc16	efec6b7d-c806-4d16-8411-6799f978abd0	6d4ae0da-8dcd-4ac7-b12f-a480469cfde6	\N	2020-10-29 13:33:15.895884	2020-10-29 13:33:15.896603	2020-10-29 13:33:15.896603	\N
e9c6ee19-8ff5-4a70-a2ac-c0f45893098b	ded156fe-6f70-4382-be09-7d234d2c6b96	4629b195-4661-44aa-8f79-aff0c32836c8	\N	2020-10-29 13:33:15.922319	2020-10-29 13:33:15.922975	2020-10-29 13:33:15.922975	\N
a3a5ac0d-99fc-4982-9925-45c5e2b1f867	b5a48f63-0d2b-4adc-9a5e-790899705b1f	5983e035-79f9-4c37-ac7d-cb3073061ddf	\N	2020-10-29 13:33:15.955816	2020-10-29 13:33:15.957269	2020-10-29 13:33:15.957269	\N
287341de-a941-4688-abc1-ea3ac95748b0	be63489c-9dda-4f24-9e71-034726d6e36f	3fa6a37d-0f4e-4401-93e0-fbad77f3aa37	\N	2020-10-29 13:33:15.999453	2020-10-29 13:33:15.999875	2020-10-29 13:33:15.999875	\N
e8edd58e-6a41-4a4a-9c74-061943d6c3ac	b8ed6a10-0dfe-4d97-831c-05fc9f5373f0	917ceb39-97ef-459e-bd87-a147cfaf7f58	\N	2020-10-29 13:33:16.01626	2020-10-29 13:33:16.016632	2020-10-29 13:33:16.016632	\N
182c92f1-4b04-4159-aec6-4c5db97b317a	232379cc-ddd7-4daa-8be9-8f62ee22cb52	f91ac06d-1e62-4851-a01b-d19ed0a46376	\N	2020-10-29 13:33:16.033271	2020-10-29 13:33:16.03367	2020-10-29 13:33:16.03367	\N
fcf75277-8b78-48dc-98e5-e490e377d8b4	1c2601be-1ac3-4061-87e1-472d353e862b	65f1402d-f87f-41ef-abfc-33728da52900	\N	2020-10-29 13:33:16.050772	2020-10-29 13:33:16.0512	2020-10-29 13:33:16.0512	\N
0830be19-c5eb-4846-8a7f-31d365510ee3	c77087a4-e18c-4661-bd3d-daa61dd08d2c	22c43fad-a272-42b5-ab30-aa7982be49e8	\N	2020-10-29 13:33:16.06767	2020-10-29 13:33:16.067991	2020-10-29 13:33:16.067991	\N
faab1a8b-7d0b-45a4-9e1f-73c7c6d8b383	a380b06e-a462-46a5-937d-9ea29b783206	bd8c7c85-eba8-45fe-8efc-9ad6e889042a	\N	2020-10-29 13:33:16.083971	2020-10-29 13:33:16.084377	2020-10-29 13:33:16.084377	\N
cd42fb14-f624-4ec3-8aee-5bb4483a08ac	640df930-589b-4a98-8a6a-06be0c74b358	13f4a358-0066-4996-adea-d3857c71b629	\N	2020-10-29 13:33:16.102808	2020-10-29 13:33:16.104425	2020-10-29 13:33:16.104425	\N
02a66941-cb54-4026-9157-f13c55ec2f9c	6cd5f3f6-43a0-4f62-bba1-111986f7ea41	d276387f-bd6e-4383-ba3d-44e5ef359f73	\N	2020-10-29 13:33:16.144238	2020-10-29 13:33:16.144864	2020-10-29 13:33:16.144864	\N
e54238cb-204e-4351-b3eb-6dfaf6005286	d4afc1df-7878-4809-b3a4-569963f909e0	0eef62f7-d5e0-4453-a329-c92882b30f9f	\N	2020-10-29 13:33:16.163377	2020-10-29 13:33:16.163833	2020-10-29 13:33:16.163833	\N
d6358965-62b3-42e9-b679-657cb86b040c	f66c8027-81dc-4f45-b55e-bd6f27465e2f	7b0f65b3-fdb6-44ac-8224-5510acd53fc2	\N	2020-10-29 13:33:16.181204	2020-10-29 13:33:16.181656	2020-10-29 13:33:16.181656	\N
81b816ae-f128-46a6-97e2-2c70b32358e1	7b92be52-1ac1-4528-8264-9b1abfb5dd35	14f7907a-82aa-499e-a6da-dbe1b0cec4ba	\N	2020-10-29 13:33:16.19863	2020-10-29 13:33:16.199085	2020-10-29 13:33:16.199085	\N
16aec265-8340-4b42-b14d-209b75de2098	21dcc367-843c-4590-b5d6-6f7fa12d0f4e	590e72e6-c170-43da-a020-84e542567a82	\N	2020-10-29 13:33:16.217353	2020-10-29 13:33:16.218937	2020-10-29 13:33:16.218937	\N
fb45fa6a-669c-490a-8e01-ece4452b78a5	bc10ef19-c189-4e73-a717-6051b26724a5	fabfa4e5-f28b-4cf8-9241-1b007008811d	\N	2020-10-29 13:33:16.270765	2020-10-29 13:33:16.272312	2020-10-29 13:33:16.272312	\N
ca9f7cae-f711-4851-a6b9-8e0fb3ee9cea	de2394ab-2bc8-4d2b-9f12-7f669e8369c8	c4c19303-966a-4ad5-a7d6-41935c2cce59	\N	2020-10-29 13:33:16.316581	2020-10-29 13:33:16.317294	2020-10-29 13:33:16.317294	\N
4ac00a91-9ec1-4be8-ba53-ea0ab9381da8	a87deb12-d67a-47bb-b398-512c8830aca0	21243d97-684b-4988-9c4e-616b50f2cd54	\N	2020-10-29 13:33:16.342556	2020-10-29 13:33:16.343232	2020-10-29 13:33:16.343232	\N
142ecee7-48a9-4175-adf6-0ae0d229c063	decc1d7c-0a73-4d22-bc69-f9cfbbb6f8c3	d93d66b8-5172-4a30-a37e-be63993ee430	\N	2020-10-29 13:33:16.368671	2020-10-29 13:33:16.369326	2020-10-29 13:33:16.369326	\N
b5312a0f-6ecf-4668-b056-fc85340ba986	72a9d447-234a-4c9d-8022-94562fb36fb4	3fedc464-d5e9-4601-9b3b-94a234d7d820	\N	2020-10-29 13:33:16.394279	2020-10-29 13:33:16.394903	2020-10-29 13:33:16.394903	\N
a3030b5f-f7ca-49de-a1d7-b8e526db7d09	5d248f25-9c3b-49bf-b30b-d356fc4516b5	4d8ada33-086a-4253-9ce6-3eec768e1f7c	\N	2020-10-29 13:33:16.420408	2020-10-29 13:33:16.42108	2020-10-29 13:33:16.42108	\N
99204233-9c4f-4308-b2a1-f7e460ad75d4	7c3a41ba-c724-4922-9daa-b2dce01223fe	df48d185-7bcd-44bb-acf7-ec43457f8e02	\N	2020-10-29 13:33:16.450891	2020-10-29 13:33:16.451529	2020-10-29 13:33:16.451529	\N
63276aa4-311b-48ea-a20c-eeef4957e6b8	a9e74040-0163-4af6-8e6f-4a19591a3f35	853cd528-4a57-4bbc-ab85-adc7a974f18f	\N	2020-10-29 13:33:16.476182	2020-10-29 13:33:16.476902	2020-10-29 13:33:16.476902	\N
ee3dd1df-1c37-4152-88eb-4081121e9633	ac556065-421c-4f84-bb6c-bb4a500ea93f	69fbd6cc-d768-42d2-a56f-e51b46506cbc	\N	2020-10-29 13:33:16.499186	2020-10-29 13:33:16.499578	2020-10-29 13:33:16.499578	\N
ac55eff9-5dbe-40e4-ba28-a176ba530733	97650f3a-2640-47d8-a2d0-2d150ee75a96	e624cd72-1cdc-4001-884a-ff657e2ec1f4	\N	2020-10-29 13:33:16.51562	2020-10-29 13:33:16.515921	2020-10-29 13:33:16.515921	\N
e3f5903d-2a94-494e-89cf-4b35eca7bba1	0ebe6f08-280e-40d8-9303-43f5283e2609	5e384300-4734-434d-98e5-fe9bb2c51d79	\N	2020-10-29 13:33:16.530914	2020-10-29 13:33:16.531256	2020-10-29 13:33:16.531256	\N
7b2910e6-6ea1-4861-a842-e8183ceee0ff	708e5106-b63a-44d1-acb5-b991219f9e3d	3e90c9f0-1aa2-4c19-9c12-e2c8d2657b5f	\N	2020-10-29 13:33:16.546011	2020-10-29 13:33:16.546301	2020-10-29 13:33:16.546301	\N
569f4d87-4e37-4df7-b7f8-26a062c31ab2	e3ed2b6a-422c-42e0-b672-f397d391ce0c	73464c75-923a-45d9-bd39-1332ec2ad624	\N	2020-10-29 13:33:16.562102	2020-10-29 13:33:16.562514	2020-10-29 13:33:16.562514	\N
9d996dc2-48d8-4478-82e4-35f28e005f0a	1c691122-2993-471e-8092-013e319880dc	70a92233-3bf5-470b-afc0-ef5919903bad	\N	2020-10-29 13:33:16.578612	2020-10-29 13:33:16.579049	2020-10-29 13:33:16.579049	\N
bbfb7989-8723-4f07-8612-bf713afeb8a3	ae7a08b7-452c-42f5-8116-331823a4f05c	2765389c-f10f-4a1d-bb56-d902f597aaa1	\N	2020-10-29 13:33:16.595208	2020-10-29 13:33:16.595649	2020-10-29 13:33:16.595649	\N
f45e53f5-decb-4803-97e1-35bebbfe7f6d	2471d231-f6c5-4e9c-a711-b085a06903e9	9f8fa9e7-4206-4244-ab24-22303eb2f4ad	\N	2020-10-29 13:33:16.612236	2020-10-29 13:33:16.612666	2020-10-29 13:33:16.612666	\N
7ab6dcc9-a8e4-4aea-8c36-6fbfa0257611	7b8ff75a-b699-466f-bc79-563de6837f11	310f7428-736a-4084-94d8-c5ef2baec831	\N	2020-10-29 13:33:16.629198	2020-10-29 13:33:16.62965	2020-10-29 13:33:16.62965	\N
f541e669-2346-4f91-8f99-dc1571b90c63	375f827a-332d-47a0-9013-46363ee4557c	979f3dbe-403e-4fde-ad13-ef335a9782f5	\N	2020-10-29 13:33:16.646054	2020-10-29 13:33:16.646369	2020-10-29 13:33:16.646369	\N
d8d8930b-4a25-4272-ab47-93937e3607e2	3bacfedd-9eed-49ed-99c9-0823cf59c9ef	48f10f78-627c-485c-b04e-31dce3a60d53	\N	2020-10-29 13:33:16.661453	2020-10-29 13:33:16.661737	2020-10-29 13:33:16.661737	\N
7a2e3c1a-7146-46b6-9f3e-1fb55fdb1867	0133afed-0cb6-4697-a729-e0c1a3ff8bc2	8fb6f6d8-f1dd-4076-9575-8b07e919ffb6	\N	2020-10-29 13:33:16.676428	2020-10-29 13:33:16.676731	2020-10-29 13:33:16.676731	\N
c126b06c-ea81-45d9-bbbd-467f3073710a	90c8c50a-b4ec-4143-b637-3d9e75518be9	880b1c51-b7b1-4b2b-bee7-e9d43488fe78	\N	2020-10-29 13:33:16.693684	2020-10-29 13:33:16.694003	2020-10-29 13:33:16.694003	\N
a125091b-90af-4cb8-8ea7-af91be8baa9a	57d2afef-9fd2-4a4a-a996-d4a86f36abaa	b6dc3fc5-dad7-4c90-99e1-3cd566a18c80	\N	2020-10-29 13:33:16.71046	2020-10-29 13:33:16.710782	2020-10-29 13:33:16.710782	\N
4ce7a9ee-ccd6-4ed6-9f37-123a04750764	9fc19cae-097c-4770-bc7e-73a1f9d15c4e	7289c9d8-84e9-43d3-80bb-6b72281ab803	\N	2020-10-29 13:33:16.726321	2020-10-29 13:33:16.726707	2020-10-29 13:33:16.726707	\N
3ef42e74-2014-471d-b240-19109c0e723c	7f8e17a2-548b-4d4f-938e-0dc3d4b49782	1cd4b228-a006-44d4-96bf-8e2686c76216	\N	2020-10-29 13:33:16.742876	2020-10-29 13:33:16.743288	2020-10-29 13:33:16.743288	\N
1982f6b4-cb6b-4bd5-b1e8-3f63a0e8b28f	83b9638e-fe6d-40c4-85e4-30c5dcc9881a	c917f6f3-e60b-4d9d-8498-ec9b2c29db32	\N	2020-10-29 13:33:16.759429	2020-10-29 13:33:16.759766	2020-10-29 13:33:16.759766	\N
6da22db8-6929-4874-851d-b3c68da883bc	61e369da-3c06-4123-93b1-4e485a25b1b7	19c0dba8-9258-49ab-a5f1-791b2d58a84b	\N	2020-10-29 13:33:16.775857	2020-10-29 13:33:16.776261	2020-10-29 13:33:16.776261	\N
8fb5b738-d973-4dca-aaf0-6f808a293b6d	aecfa6ad-f932-47df-bcd0-b4eec9f9bf08	131fd0d9-e22e-48ea-b27c-c8bae00a615b	\N	2020-10-29 13:33:16.792121	2020-10-29 13:33:16.792528	2020-10-29 13:33:16.792528	\N
dc09c6de-f783-46a4-a88f-615227063a46	e6f4c99a-7b2f-4891-b39c-d5ae4fd0dfb6	e2c73122-c4f9-480a-8615-f79a45f4a0d2	\N	2020-10-29 13:33:16.808384	2020-10-29 13:33:16.808791	2020-10-29 13:33:16.808791	\N
07de3bd7-69c0-49a4-bec7-d82a9deadf41	6fa9b292-1397-4b30-a1d1-96cd2e51b19b	9189df52-6681-4bcb-bf53-9ddb8b04f8ca	\N	2020-10-29 13:33:16.824945	2020-10-29 13:33:16.825304	2020-10-29 13:33:16.825304	\N
096ee689-b041-43e6-b54e-2efab0c858fa	d07fbc3a-a573-4c35-9089-fa08e3661248	5d7cde15-ba21-4e91-96a9-57582a0550bf	\N	2020-10-29 13:33:16.841713	2020-10-29 13:33:16.843187	2020-10-29 13:33:16.843187	\N
cf8af9a7-88a8-4e38-abb1-66d9fece0700	648d1b55-77c6-4406-8c48-bbc40b27796c	25590caf-fb21-4b86-9ccc-ed4cafd8ce5d	\N	2020-10-29 13:33:16.89377	2020-10-29 13:33:16.895225	2020-10-29 13:33:16.895225	\N
7149ba86-409b-4d83-a396-8fba91c6a8e6	9a27872c-0741-4dbd-8230-c9674b7cc005	47b98442-53df-4c6f-9fa9-3edac0a11022	\N	2020-10-29 13:33:16.922266	2020-10-29 13:33:16.922833	2020-10-29 13:33:16.922833	\N
a549d541-3c6d-45d6-b93c-03116f2362f1	3d3cc570-4251-432c-b588-04ef0d1c7b58	7f44cee9-db74-4787-bb0a-84ef02b846c1	\N	2020-10-29 13:33:16.944417	2020-10-29 13:33:16.944928	2020-10-29 13:33:16.944928	\N
22195e64-bb75-4f9e-9283-29c92cb7e974	4719bd5a-0330-47b6-8c4b-7b0ed19c76fd	6605d208-512a-46fd-bcec-89ac1959782b	\N	2020-10-29 13:33:16.967436	2020-10-29 13:33:16.968967	2020-10-29 13:33:16.968967	\N
af26b187-1a59-4532-8ece-bc757a441b78	3f6cfe36-0dbf-4a26-be6a-0040aedff732	3837e79c-6413-46dc-9bc3-4e69e7bf79c4	\N	2020-10-29 13:33:17.019299	2020-10-29 13:33:17.02035	2020-10-29 13:33:17.02035	\N
e8a8ac24-a672-4c57-afbd-d64c4ba3e656	313e3625-6023-463a-a9ac-2bcf1973bc4d	c8d687bf-5b76-42e5-b072-894c28ddcaeb	\N	2020-10-29 13:33:17.04275	2020-10-29 13:33:17.043199	2020-10-29 13:33:17.043199	\N
c8cc2f29-04f1-48d3-b174-8a7a73492db6	42b6eba3-f7f6-4171-a238-917ef1b8dcc0	9f8a004a-f800-4f78-8271-5b3815195cbb	\N	2020-10-29 13:33:17.062282	2020-10-29 13:33:17.063952	2020-10-29 13:33:17.063952	\N
1bbddd38-1036-4ae6-8e81-a350737598f3	b64d97dc-91cb-41a0-b0ab-c6e07a21c092	5f6e15a9-4a4e-4edd-9351-188f9fefd630	\N	2020-10-29 13:33:17.089974	2020-10-29 13:33:17.090395	2020-10-29 13:33:17.090395	\N
e014f406-1e9e-4efe-aa91-56bef825b81c	345c8b73-0f57-49e5-b9d3-481fa04b3b57	a2142821-bda5-49d3-aeb9-fa17cbb84445	\N	2020-10-29 13:33:17.109855	2020-10-29 13:33:17.110341	2020-10-29 13:33:17.110341	\N
732fda0c-536b-444a-8ab6-5f0cbb7548ac	bac99b97-b615-4267-88c4-a4923be21f7a	345dfddc-ec13-4d5b-870d-6ade12d2f4d6	\N	2020-10-29 13:33:17.130616	2020-10-29 13:33:17.131164	2020-10-29 13:33:17.131164	\N
6169ef05-8e62-4058-b1d0-f8c1eac3e71b	94f51c3c-9ffb-40c3-b15e-ba3737073fde	01b4ef8b-1392-4335-8afc-84ae47f2d07a	\N	2020-10-29 13:33:17.151007	2020-10-29 13:33:17.151562	2020-10-29 13:33:17.151562	\N
cc540dcd-72d1-4f5f-b1bf-a0664d819d9d	6ac01816-daba-4142-9fd2-066986099a45	9d6a8a3e-2c25-42cb-bb47-d4f50e040228	\N	2020-10-29 13:33:17.175415	2020-10-29 13:33:17.17594	2020-10-29 13:33:17.17594	\N
322919fb-0f56-4212-bc4d-0d1b78d6e66a	930efa88-53e3-4c0b-bf33-bb35189be439	5361da06-a09d-49e0-a9da-357ae588c0b0	\N	2020-10-29 13:33:17.195621	2020-10-29 13:33:17.19616	2020-10-29 13:33:17.19616	\N
7ae2c718-76c4-4274-810d-bba25ec4fe46	ac381a0a-52cf-4926-806e-79a1fa579185	b4e3472c-c7d9-443d-904a-a75906ab9b56	\N	2020-10-29 13:33:17.236454	2020-10-29 13:33:17.237998	2020-10-29 13:33:17.237998	\N
596245cf-6f80-4602-94f3-ace7359daa52	37014aa9-21db-4637-82f5-a5d3adb71fb5	6b07934a-d97c-412b-8a29-ec82631df446	\N	2020-10-29 13:33:17.264131	2020-10-29 13:33:17.264601	2020-10-29 13:33:17.264601	\N
c7b92fd7-a11d-48c0-bdf3-972c44aa1e95	9e550a65-98ca-45e6-aad1-cb2bfe2c9d0b	01840676-cd76-448f-b3e4-c5e9519d2b5d	\N	2020-10-29 13:33:17.281714	2020-10-29 13:33:17.282096	2020-10-29 13:33:17.282096	\N
3da6c786-488d-4b6c-a3e4-8a86baa53d15	7236a3ad-6155-4bda-9673-272de8f48a49	49985697-10e2-4af7-b265-ae2714c461f2	\N	2020-10-29 13:33:17.298344	2020-10-29 13:33:17.298739	2020-10-29 13:33:17.298739	\N
c77bedb4-86ee-41a0-a251-8b3dfa535d08	575e0f76-69e4-472e-b699-05db6f8a99c7	1630134f-60b1-447d-ac75-0300ea7a8a77	\N	2020-10-29 13:33:17.348712	2020-10-29 13:33:17.350298	2020-10-29 13:33:17.350298	\N
7754213f-d326-4aee-94ca-b0d07ec66156	2d5199ab-d7cb-4cdb-80f7-3d48eed63d58	286e59fb-c7d8-44a5-a93b-ca99a1165135	\N	2020-10-29 13:33:17.384342	2020-10-29 13:33:17.384876	2020-10-29 13:33:17.384876	\N
7fe66d4a-0436-4d1e-a0c4-eca302670531	7712e4f5-0c77-4594-9996-38d283f77fc5	2b11b78f-260b-4056-b2eb-d6b18352e69a	\N	2020-10-29 13:33:17.401968	2020-10-29 13:33:17.402978	2020-10-29 13:33:17.402978	\N
dfc6b2d6-4e8f-457f-8697-500da11ac537	7ea89469-b582-4abe-8859-ce62af920071	3c3bb90f-dffc-4216-822f-e7fd6ccd47f5	\N	2020-10-29 13:33:17.427198	2020-10-29 13:33:17.4287	2020-10-29 13:33:17.4287	\N
348584b0-584f-4c37-9b54-47563e88a727	cedfa717-88c9-4adf-ad3f-5b44a6a58517	8c83a97a-4cd4-4e51-9d1b-4279adef5ca2	\N	2020-10-29 13:33:17.454542	2020-10-29 13:33:17.455053	2020-10-29 13:33:17.455053	\N
aecefe23-42c0-4df8-8323-859650da997a	305a5648-bf49-48da-8ada-c65bde17bf37	c3fb1069-4dbb-4696-a326-c950e0025ef5	\N	2020-10-29 13:33:17.474101	2020-10-29 13:33:17.474619	2020-10-29 13:33:17.474619	\N
d394fdfd-308f-4c31-93dd-fe9ee33597a0	4c3c57f3-643a-42ce-b482-01e4ee3ab4ee	4833cf74-cf29-4d53-b8e5-5140472efd48	\N	2020-10-29 13:33:17.493889	2020-10-29 13:33:17.494454	2020-10-29 13:33:17.494454	\N
bff094a3-44a1-4004-9b7a-c8ba9e05c599	120f69a4-0d69-409b-8598-816426be9767	73385252-fb0f-466c-b008-321e70cab489	\N	2020-10-29 13:33:17.513329	2020-10-29 13:33:17.513843	2020-10-29 13:33:17.513843	\N
474780f1-f4c3-4fb1-b2e0-853df1e111b5	bee9ba94-8a07-4046-a60c-65d9487337c9	4f748f81-0dcb-4c1f-9fcb-9b3aa4beb721	\N	2020-10-29 13:33:17.53335	2020-10-29 13:33:17.533875	2020-10-29 13:33:17.533875	\N
3f689f68-7dc8-4a86-ad60-2d351dfa98a7	368da47a-9db8-47cd-9519-565489e7cb8b	11d4842d-b7df-4ad5-9edc-a26adc3f84d1	\N	2020-10-29 13:33:17.55361	2020-10-29 13:33:17.554147	2020-10-29 13:33:17.554147	\N
7e47df92-ffda-47db-a1f8-146b14d8d631	8b1842fb-4988-4b41-98c0-a3638285519c	046a6186-bc15-469d-b4bf-9fb6fae6de60	\N	2020-10-29 13:33:17.573478	2020-10-29 13:33:17.573972	2020-10-29 13:33:17.573972	\N
00cba156-b312-43b8-9c4b-744877036ece	f5dbf128-de9c-4c63-8be2-3143d271fdbe	102ff072-00bc-4c23-ada0-ec20e261a966	\N	2020-10-29 13:33:17.593156	2020-10-29 13:33:17.593626	2020-10-29 13:33:17.593626	\N
ff34e542-454a-48ca-906b-f1158916c5ab	c66f6c7a-0d11-41dc-867a-9a4cc974ba48	82b864e5-a3bf-43c5-a843-0d9271c176b9	\N	2020-10-29 13:33:17.612919	2020-10-29 13:33:17.613437	2020-10-29 13:33:17.613437	\N
68ceb7b6-d719-4a0c-bed8-8be9250db557	4460ed72-0136-4743-b53a-77d10c41e84a	b6687c63-d127-4a14-ab4b-6eae3c2a64c7	\N	2020-10-29 13:33:17.66257	2020-10-29 13:33:17.664025	2020-10-29 13:33:17.664025	\N
bd5ce77d-47b8-4373-a591-d8ffada8dd36	b6f893cc-3136-421b-9475-e6d199fd5c97	6247e58b-3251-4938-a4ea-8991fd31a87e	\N	2020-10-29 13:33:17.689427	2020-10-29 13:33:17.689957	2020-10-29 13:33:17.689957	\N
1357ded4-afdc-411d-b196-58721f5d34b4	cabef119-e7c6-4a75-8a8d-eee555796b80	64a8381f-e0a5-47eb-bb59-899330f0c57b	\N	2020-10-29 13:33:17.707458	2020-10-29 13:33:17.707935	2020-10-29 13:33:17.707935	\N
6fb13adb-1f3d-4254-a2ae-8c470e67d579	abda1a65-f18d-4c76-94bc-869793906985	59d21e6c-7d7a-427c-9c6d-48605787a79a	\N	2020-10-29 13:33:17.726029	2020-10-29 13:33:17.726526	2020-10-29 13:33:17.726526	\N
3225311f-758b-41b4-ab64-529ad7b2a77a	0ed6b36f-0784-463f-b9a3-f2373328b135	29fe6d08-4246-41b3-8184-34be970331f2	\N	2020-10-29 13:33:17.745949	2020-10-29 13:33:17.746336	2020-10-29 13:33:17.746336	\N
975b530d-c2ac-44de-8abd-18628841ae5f	eb09c086-c8fe-47f9-83b8-b4bf655a4aa7	46897f07-74ef-4d26-b978-91a379908542	\N	2020-10-29 13:33:17.763771	2020-10-29 13:33:17.764193	2020-10-29 13:33:17.764193	\N
23b70aac-8438-4f9f-8c30-d61eba505ea0	055d4bb3-0008-42c4-95cf-26d40f9f7dc5	09216daa-8fdc-41f6-99d4-3b90ad48427f	\N	2020-10-29 13:33:17.782267	2020-10-29 13:33:17.782709	2020-10-29 13:33:17.782709	\N
a3b83d0d-9f1b-4805-bb52-1971f4794b73	1e2baea2-605b-4813-9295-6ff522bb14f5	23f0e823-3359-4f85-9153-efac7cd00df7	\N	2020-10-29 13:33:17.800782	2020-10-29 13:33:17.801216	2020-10-29 13:33:17.801216	\N
e9b1ff75-2590-4738-98f9-9e9bcb6ae6e2	360549b9-d28b-4ed4-9cae-766e6de27397	d1b66578-0e58-47df-9bc3-96b0aedce23f	\N	2020-10-29 13:33:17.81919	2020-10-29 13:33:17.819632	2020-10-29 13:33:17.819632	\N
c556939e-0c19-4a16-8fd0-1f9bfc05b6be	353d6829-61e1-4081-8055-921757314ab1	835249c6-2290-46f0-b61f-ae710a6da88c	\N	2020-10-29 13:33:17.837115	2020-10-29 13:33:17.837638	2020-10-29 13:33:17.837638	\N
f28b5845-105b-4f86-8607-ed5e59b0d689	649513cf-ca0a-4b95-8896-6b92b2ef5d04	253f2092-d981-466f-aae5-7ff01e386e36	\N	2020-10-29 13:33:17.857677	2020-10-29 13:33:17.858234	2020-10-29 13:33:17.858234	\N
a7228a63-59e4-446b-9962-603a904f52fd	a0ba054a-1473-436b-8747-d005e63c2033	aeeced19-e7b4-40ea-8446-7af5d670b735	\N	2020-10-29 13:33:17.878289	2020-10-29 13:33:17.878847	2020-10-29 13:33:17.878847	\N
6ced1a4c-3f62-4ed3-bd71-9af4a5463e02	8e173185-6f2b-4d25-ab29-79c039bee9fa	a18568f2-dfa0-4378-a99e-780db156f192	\N	2020-10-29 13:33:17.899552	2020-10-29 13:33:17.900059	2020-10-29 13:33:17.900059	\N
0af5cea8-1f5f-4fcf-addd-5b60519227f0	9307dbb9-5620-4682-b7a9-379c4640526e	a31fbd77-f197-4d47-8205-10f1830656fc	\N	2020-10-29 13:33:17.923238	2020-10-29 13:33:17.923789	2020-10-29 13:33:17.923789	\N
524d87ed-11fe-4031-901f-9c5b37f8892c	84686bbb-c984-4790-9225-5ee9b7250841	c14ce860-8653-4e5c-9a8e-4fadaa1c4cff	\N	2020-10-29 13:33:17.945289	2020-10-29 13:33:17.945826	2020-10-29 13:33:17.945826	\N
4c89fcc9-6c81-41f3-a254-63a4ab341bb9	47650299-7a33-407e-abb5-b75ad0325707	5acf2e9a-8cbd-4eb8-964b-efdb84ba4567	\N	2020-10-29 13:33:17.970972	2020-10-29 13:33:17.97155	2020-10-29 13:33:17.97155	\N
cf8b4fe1-ea27-4d3c-92f7-2f27e582d891	d09e416d-77dc-4622-b695-8762682715b5	86f82a47-c5e3-4a9d-9292-99387fbe9adb	\N	2020-10-29 13:33:17.995984	2020-10-29 13:33:17.996595	2020-10-29 13:33:17.996595	\N
4c17663c-510e-4c83-bbc8-87c2d7289e74	1eab005f-191d-4580-b2f3-7200f66c1f39	5bceef0b-98c1-4787-bbc6-33feb410844b	\N	2020-10-29 13:33:18.01651	2020-10-29 13:33:18.016926	2020-10-29 13:33:18.016926	\N
789ee3ee-65bd-46f5-92ba-1502d93554b4	b71551ef-34d2-43a1-8646-cf8a2fd01ac8	fd14f83d-86d0-4864-ba9a-a74af0c39413	\N	2020-10-29 13:33:18.032725	2020-10-29 13:33:18.03314	2020-10-29 13:33:18.03314	\N
10c83576-30bf-4032-85aa-32da97742a7b	8c222885-c9cd-4c2a-9a41-be7dd200a7aa	fef44cc5-3c2f-4202-89c9-291522c62728	\N	2020-10-29 13:33:18.069824	2020-10-29 13:33:18.070723	2020-10-29 13:33:18.070723	\N
0a272d4a-23f9-412a-b83e-6afa68c68d10	01b54d28-9085-4b72-a079-c2bc4546919b	bfd59454-c187-4893-9ad2-a11664d95770	\N	2020-10-29 13:33:18.093061	2020-10-29 13:33:18.093545	2020-10-29 13:33:18.093545	\N
eb9c03b8-7af3-45de-a1c6-d04d33673c15	531836f8-a19f-49dc-9ba4-2bc89edeb058	62b9ea7c-4d9b-4ffb-9384-ee4e6f712cf4	\N	2020-10-29 13:33:18.124003	2020-10-29 13:33:18.12557	2020-10-29 13:33:18.12557	\N
be55ad25-926d-49d5-8de0-59947128c38f	ad5e3c39-9f7d-4f34-9d42-9f555bb5c0e7	be874081-1efd-4544-aba1-f7fe31775bd3	\N	2020-10-29 13:33:18.173438	2020-10-29 13:33:18.174219	2020-10-29 13:33:18.174219	\N
268dce2c-1b31-40ed-80e9-c8bc3205a023	fe91233c-362b-4518-bd71-3a2612ebcdac	d33c4cc3-a89e-459a-a809-6126c0cfb7c2	\N	2020-10-29 13:33:18.196327	2020-10-29 13:33:18.196816	2020-10-29 13:33:18.196816	\N
20df777c-7a98-4f9b-9c61-2c22e027ea18	fedb267b-2ed6-46c6-89c2-1804f5776b0c	93a436d4-74a4-4bff-90ea-4f3887644cfe	\N	2020-10-29 13:33:18.21821	2020-10-29 13:33:18.218803	2020-10-29 13:33:18.218803	\N
6735d0ae-0eb1-427b-8892-3964b0506bd5	6ac2b47b-8290-4bf8-b4b0-95b7f308035f	80f58998-61ab-4c04-9f72-34c05b4de5e0	\N	2020-10-29 13:33:18.239249	2020-10-29 13:33:18.239718	2020-10-29 13:33:18.239718	\N
094bdcb9-1776-4981-a334-3fbf0639df91	a5ecdd95-040f-437c-8867-06001bb81275	b35c32a5-89a1-4446-892b-1ba85490ed92	\N	2020-10-29 13:33:18.259621	2020-10-29 13:33:18.26009	2020-10-29 13:33:18.26009	\N
091a3be4-eb3e-4be0-9b07-3d8178bb90fd	6fc79cc8-498d-4f41-980c-bb895c0e2bc1	b198cfbc-31fe-4bcf-90c1-3db9fa17839b	\N	2020-10-29 13:33:18.276822	2020-10-29 13:33:18.27711	2020-10-29 13:33:18.27711	\N
3a044174-f89a-43b7-a521-d9a787108549	9e1a79df-491f-44bc-976a-8a47381c2155	2e7532ed-ccac-4c4e-b425-a36673db68b8	\N	2020-10-29 13:33:18.293381	2020-10-29 13:33:18.293668	2020-10-29 13:33:18.293668	\N
df18457c-2461-44e8-a7cf-aec06768c6cf	8309308f-0f6e-4fe4-a19d-4304f5b26360	818d2413-79ab-4d2b-8726-549fc4bc892a	\N	2020-10-29 13:33:18.307796	2020-10-29 13:33:18.308102	2020-10-29 13:33:18.308102	\N
6e367441-9c24-494c-97ff-787cb4b71aab	53ab2dc1-19be-462c-9f80-c039f1fe1e9a	e3dc7401-0d98-45d0-829c-093af57ca1d7	\N	2020-10-29 13:33:18.321876	2020-10-29 13:33:18.322176	2020-10-29 13:33:18.322176	\N
2eaef553-d955-40d7-99c8-110782a085f2	1c8f156a-0dba-466f-ae53-49cfeac77e4c	f41166f1-802b-4071-b582-95310684117a	\N	2020-10-29 13:33:18.336679	2020-10-29 13:33:18.337057	2020-10-29 13:33:18.337057	\N
1cee2e10-0484-4c77-8ac4-246a815f633b	ff55c46e-b6c9-4afc-836f-e9c838f06e0e	f0ae6ef3-d4fa-4a4b-9116-d02658f6b9df	\N	2020-10-29 13:33:18.353317	2020-10-29 13:33:18.353636	2020-10-29 13:33:18.353636	\N
135af8af-3d4b-4d24-afd5-bf5fb49fc87b	c1f920b5-ff65-44fa-a9f8-4df21f8cad64	3193afe6-9274-47b8-b936-413630e5753a	\N	2020-10-29 13:33:18.38625	2020-10-29 13:33:18.386763	2020-10-29 13:33:18.386763	\N
45a27248-a02b-42e5-86c1-1619d9e742ac	47d516d2-034f-4b2c-8f1f-12d64d8949a1	e622c6fa-a84d-4208-b278-e6e1e2e154c7	\N	2020-10-29 13:33:18.404758	2020-10-29 13:33:18.40518	2020-10-29 13:33:18.40518	\N
424f8649-f026-4e34-98d6-9fff86e55264	c334e188-a022-4317-81d7-e8081934f099	0707a602-c944-472c-810e-5377f0035909	\N	2020-10-29 13:33:18.421385	2020-10-29 13:33:18.42178	2020-10-29 13:33:18.42178	\N
3f186d40-6c62-4888-b334-864b514995c1	e17a7cb2-2827-4cd3-89f9-e5dc082ca8d7	61f4ccb3-15f1-4969-bc2d-eb774f99a6cd	\N	2020-10-29 13:33:18.436663	2020-10-29 13:33:18.437061	2020-10-29 13:33:18.437061	\N
4b953899-5246-435c-b8c8-1e8c79313eae	39c88479-be41-477d-8357-a3c1482817fa	d4e70a81-279c-4843-b1a1-ac472aa3e9cc	\N	2020-10-29 13:33:18.453009	2020-10-29 13:33:18.453444	2020-10-29 13:33:18.453444	\N
0086fe8b-5a3b-4148-be70-820afc71ee4b	24486882-8d87-4ec7-a731-e2cb42bc3b43	18248783-e520-4291-b0bf-d78a5b4e03cc	\N	2020-10-29 13:33:18.468954	2020-10-29 13:33:18.469237	2020-10-29 13:33:18.469237	\N
01571979-a81b-416d-b918-0e1b258bf5f1	c410a25d-f7de-437e-b29e-f24804288f00	5f0f395d-81af-41ff-a79c-2daa7d3fdec1	\N	2020-10-29 13:33:18.498666	2020-10-29 13:33:18.499356	2020-10-29 13:33:18.499356	\N
75d8be55-ef18-42de-95c0-f4d1871ac834	3bb941e9-984e-4c31-bc14-db4fdb3ff1da	813a3766-2cc7-400a-8ca3-504a94ea8d46	\N	2020-10-29 13:33:18.520355	2020-10-29 13:33:18.520777	2020-10-29 13:33:18.520777	\N
65a1a9c5-6663-4b70-bba4-1889b52e9abb	c9f5e046-7c4b-4105-adf6-33eabaea08d7	9b305531-f99d-49b4-9285-2a07ca7f16de	\N	2020-10-29 13:33:18.539441	2020-10-29 13:33:18.53981	2020-10-29 13:33:18.53981	\N
0d9939f7-69c0-417e-bf9e-b6f29870ec59	061295df-a106-4667-ac63-06b04b751558	bda90623-3298-4d31-9d1a-a4232138a5c9	\N	2020-10-29 13:33:18.556572	2020-10-29 13:33:18.557005	2020-10-29 13:33:18.557005	\N
26baae4b-09dc-4932-bc87-915ce78ce68d	53fd02e6-2b9c-4a86-affa-78af86b24468	2ec93c5e-0a9b-4ec9-8151-b9514d2cf522	\N	2020-10-29 13:33:18.574353	2020-10-29 13:33:18.574767	2020-10-29 13:33:18.574767	\N
41c95215-16bb-4ad5-bf71-b6d5c72bd495	5383bc7e-73d0-4787-84c0-404171c5ab53	aadeed45-9435-466c-81c5-c26db07327f2	\N	2020-10-29 13:33:18.592121	2020-10-29 13:33:18.592573	2020-10-29 13:33:18.592573	\N
8ce53cfc-f461-4576-b39a-65a84b987860	68591a89-cd6e-48ba-a593-51148989e813	29d094a1-639b-4183-85a5-edf40ec6670b	\N	2020-10-29 13:33:18.612031	2020-10-29 13:33:18.612393	2020-10-29 13:33:18.612393	\N
b31ccce4-643c-4e22-b34d-26f976b46c9a	5166332c-e246-40b4-a059-a5fb67720113	0a1cc10a-42c5-472a-996e-617c7c24b51a	\N	2020-10-29 13:33:18.636863	2020-10-29 13:33:18.637358	2020-10-29 13:33:18.637358	\N
ae77e3c2-a56c-48db-8370-b152f1096a67	7cb5ad86-4a39-4060-a0d5-0ea00e724d90	1403b80e-53e8-41c9-8d0d-45cfdeacfbff	\N	2020-10-29 13:33:18.67519	2020-10-29 13:33:18.676715	2020-10-29 13:33:18.676715	\N
2ee12f50-cb02-4678-b64c-a1b0789bf917	21ebfd87-2205-4dd4-ba72-60d282332e01	3a68f1d3-8507-4b3c-a0bd-74d4d64b830f	\N	2020-10-29 13:33:18.719579	2020-10-29 13:33:18.720259	2020-10-29 13:33:18.720259	\N
6b2a0b68-7244-4dd6-a596-a03b35c4d868	667926be-2ab3-47cf-b85a-0406cc8f374c	4f8713d2-1080-4a6a-8f7d-dcec346d7ff4	\N	2020-10-29 13:33:18.742594	2020-10-29 13:33:18.743158	2020-10-29 13:33:18.743158	\N
a3b41694-adb9-4f88-bca5-8d93da1f1f02	e3a409e9-b985-4a0d-a23c-67679b09bf05	cc55150d-3ead-48dd-a484-ee194acb5984	\N	2020-10-29 13:33:18.765111	2020-10-29 13:33:18.765622	2020-10-29 13:33:18.765622	\N
52c0cf1d-b812-44f8-88d8-484bb0693f2f	c2f2f273-ace6-4484-838f-549a6a78bf92	45a51ead-4ecd-4422-9462-fac73395ac67	\N	2020-10-29 13:33:18.789055	2020-10-29 13:33:18.789689	2020-10-29 13:33:18.789689	\N
107b5ac4-760a-40bf-8e3f-b541b75a31f8	7618c153-ab69-4df5-913f-2cb6604fcc17	29cc7444-8547-47a8-b3cc-dc2331543e9c	\N	2020-10-29 13:33:18.821138	2020-10-29 13:33:18.821805	2020-10-29 13:33:18.821805	\N
cef67493-4fcd-4052-8e50-833cb3da60db	572b4401-9ab3-4439-9f76-f59213251dfd	c60cacdf-ee5d-4671-b17b-6a283e9cde23	\N	2020-10-29 13:33:18.846423	2020-10-29 13:33:18.846988	2020-10-29 13:33:18.846988	\N
27719711-7280-4cae-b64a-31f007f55696	1cb79dcc-5840-4dfc-9f2f-85af9bd6653a	ee7e929b-05e7-44e6-ac90-906a2eb1cc30	\N	2020-10-29 13:33:18.865158	2020-10-29 13:33:18.865526	2020-10-29 13:33:18.865526	\N
165f22e5-fc0c-4dd3-9d1b-e8bddc0ba85c	45d34cda-9428-4eed-a351-1f0faba634f4	7ef35c04-22d6-49f8-ae00-1ad9ce9711c1	\N	2020-10-29 13:33:18.880772	2020-10-29 13:33:18.881051	2020-10-29 13:33:18.881051	\N
e34fdf5f-a431-465a-9129-899425a86a46	9deca05b-4df7-45f6-89cf-489f8bb81a34	87d5ff49-844c-4243-b4ff-84f64dc963a1	\N	2020-10-29 13:33:18.895992	2020-10-29 13:33:18.89627	2020-10-29 13:33:18.89627	\N
69b9c15d-b150-48bf-b739-e65231c66896	a0c34275-4526-49b5-910d-605a197d64a0	7088fb70-62d1-4017-b3fc-3d776f9cb4b6	\N	2020-10-29 13:33:18.910426	2020-10-29 13:33:18.910717	2020-10-29 13:33:18.910717	\N
94eee804-7514-41cf-b2c5-e848ffd213a3	ab3a0d1d-9386-4492-9327-2c478d4635e3	34f67b13-7d29-47ae-93a9-911818b2d42f	\N	2020-10-29 13:33:18.925007	2020-10-29 13:33:18.925293	2020-10-29 13:33:18.925293	\N
5b208d75-2c54-489a-9182-30f188300eb7	075a5d1e-31ae-40c1-ad99-c022f70fb131	8f918ffa-d8cb-4772-aee6-0fbad308a9a8	\N	2020-10-29 13:33:18.939626	2020-10-29 13:33:18.939914	2020-10-29 13:33:18.939914	\N
42e41a69-c2db-4372-8ddd-78a580c62fc7	5d13b868-4565-4226-917b-018068e3c3de	1aec1e8a-1fd8-4df2-a22d-7c52e3923c49	\N	2020-10-29 13:33:18.954681	2020-10-29 13:33:18.954977	2020-10-29 13:33:18.954977	\N
da11c494-b8eb-4d19-a2c3-e5efba570317	7be0cade-996d-491b-8168-9e50cdac6cb4	afc00d30-c4e4-4767-b20a-380f339e2c91	\N	2020-10-29 13:33:18.969803	2020-10-29 13:33:18.970073	2020-10-29 13:33:18.970073	\N
80586465-aa99-4fc6-b896-ee3ba651deb1	e07e99e6-5724-4baa-b530-32ba9764dc6d	7af786a2-a968-4476-afb2-198f9148f41d	\N	2020-10-29 13:33:18.984339	2020-10-29 13:33:18.984615	2020-10-29 13:33:18.984615	\N
1a58a43f-13f0-4645-8a1a-4c89b71ec8e6	95b1a118-f383-47e3-9294-2d35c61eec5f	56f6ba28-14c3-435a-ad2f-3b5e7e9852b9	\N	2020-10-29 13:33:18.998146	2020-10-29 13:33:18.998424	2020-10-29 13:33:18.998424	\N
3005e022-461e-4c7c-8f2f-6c88b4ee3502	02cdc5a5-e28b-4a68-8b8f-88c3deefbdb0	19fd4e36-6f63-46a5-831f-b31b5ba51b07	\N	2020-10-29 13:33:19.021689	2020-10-29 13:33:19.022262	2020-10-29 13:33:19.022262	\N
d0bd15c6-0bab-4780-ba38-f8ea94b9429b	a974447e-a401-4127-b319-10c2d8684669	be89bbb0-cccc-480e-87ec-fd708cad7e64	\N	2020-10-29 13:33:19.042291	2020-10-29 13:33:19.042733	2020-10-29 13:33:19.042733	\N
c1eac14a-9ec2-4d27-80db-f6f75271cf49	926176af-8c7f-41fc-a09a-b3fa85ec24be	73e6fd48-def4-4e8c-8e4d-d892091d2789	\N	2020-10-29 13:33:19.060913	2020-10-29 13:33:19.061381	2020-10-29 13:33:19.061381	\N
756ec4db-4d4d-40bf-84f7-e7b2ac3773bb	9fd3672f-8435-4a0f-89a1-34f8a595662f	313a6f52-df34-4fae-93b9-41bad061a64b	\N	2020-10-29 13:33:19.078679	2020-10-29 13:33:19.079089	2020-10-29 13:33:19.079089	\N
e6e450af-8137-4ccc-9f0d-0747b2e36fb4	e57b6698-6d4b-4c84-a865-02d02793ce15	a42a9cdc-6a4d-4270-b81e-20e4252f917c	\N	2020-10-29 13:33:19.097061	2020-10-29 13:33:19.097456	2020-10-29 13:33:19.097456	\N
b55f257c-9342-4d1b-a4c3-614022950224	70830b4c-9f5b-43b6-bba5-3ea2fdf534eb	427ebf7c-2ec6-4385-ac09-89a4612f5192	\N	2020-10-29 13:33:19.115139	2020-10-29 13:33:19.115618	2020-10-29 13:33:19.115618	\N
44267ad3-c308-4341-bf98-c919ff7a7047	bc33ebca-67af-42cf-b555-47a03fa5f83d	6db5985f-c130-4ba7-9dd9-587b934acc60	\N	2020-10-29 13:33:19.13448	2020-10-29 13:33:19.134948	2020-10-29 13:33:19.134948	\N
9d445559-a638-45c5-af84-b268a591fab4	0ec74da7-7ef3-4f0d-830a-2af7ae81f1bc	3f6b6cdd-4f8f-4e37-9344-14e632e62d4f	\N	2020-10-29 13:33:19.152004	2020-10-29 13:33:19.152446	2020-10-29 13:33:19.152446	\N
8f70add1-d15d-4aa9-b866-b65c205a2689	1d028def-dd4f-46f7-be83-9c24d75b3ce6	7d5bdde6-1e08-4e7b-ae08-e915c380c45d	\N	2020-10-29 13:33:19.167604	2020-10-29 13:33:19.167983	2020-10-29 13:33:19.167983	\N
3998249b-7aeb-4a71-9a21-6de4613fb328	d34c6e5c-9c59-4592-8f55-a96a37e5a20c	efc6869d-f0b6-4c83-bf53-f6caeb58ddc3	\N	2020-10-29 13:33:19.183058	2020-10-29 13:33:19.183473	2020-10-29 13:33:19.183473	\N
12b753b9-c9e3-4220-a01b-59e2daaa8803	fcd2d456-977a-475e-b659-b06bb5155b08	e9d23551-dfc1-420a-af71-0dc21ca5aa71	\N	2020-10-29 13:33:19.19936	2020-10-29 13:33:19.199722	2020-10-29 13:33:19.199722	\N
6a34961c-e2d6-4ef2-ab5e-d33eac8b1f18	b4078b48-c035-4d13-968b-ee16dac20c05	96cf989f-92d7-4f8e-b2ea-5dd929b9c8af	\N	2020-10-29 13:33:19.21557	2020-10-29 13:33:19.215985	2020-10-29 13:33:19.215985	\N
d11c06a4-bc02-4f7e-b680-5ab965ffa537	1e892a45-a9be-42c3-b02d-330f04219fc0	d1d4421f-e219-423b-bc52-120bb3047a8d	\N	2020-10-29 13:33:19.231579	2020-10-29 13:33:19.231854	2020-10-29 13:33:19.231854	\N
bb619dc1-760e-4968-94ef-605799cb85ff	6686ac5a-a130-4d2b-a188-3df64af56d80	7efabcd9-7411-4ebc-a698-f14efc23e811	\N	2020-10-29 13:33:19.246158	2020-10-29 13:33:19.246447	2020-10-29 13:33:19.246447	\N
64d6f7a1-714d-4f8e-b66b-7c121f9e5702	51f9aebc-33a5-435f-92a4-0d02f48c2bbd	225d58ba-0e4f-406d-a2b1-9ad82af5af27	\N	2020-10-29 13:33:19.263295	2020-10-29 13:33:19.263598	2020-10-29 13:33:19.263598	\N
24a669b1-eeca-4a6c-9e19-9ae738e49ba5	54cc9d01-4bbf-4e14-9490-3aa60ee6e509	2845803b-cab7-45d2-a367-7941401945ab	\N	2020-10-29 13:33:19.278334	2020-10-29 13:33:19.278615	2020-10-29 13:33:19.278615	\N
1b66f0f7-71f0-4b3d-993a-ec133d69d188	46282f40-8d56-49ce-a390-a27ef409d5a5	ae377184-38f8-4538-b4af-8a0146bb1c7a	\N	2020-10-29 13:33:19.293363	2020-10-29 13:33:19.293659	2020-10-29 13:33:19.293659	\N
aeb79679-9b79-46c6-a83b-5f4997e7f06e	5eef1aa9-daa4-45b8-9c86-93ba94df95e9	3b91ce94-5fd9-4d87-a3fe-66d4fc4f074f	\N	2020-10-29 13:33:19.308659	2020-10-29 13:33:19.308946	2020-10-29 13:33:19.308946	\N
50fdec22-be96-4985-a4ae-7abbff4a1f19	63c616ec-1e12-41ce-9e91-b1ed9e76be0b	d8408818-8026-4db5-be2a-1c31a38f7d81	\N	2020-10-29 13:33:19.340145	2020-10-29 13:33:19.341755	2020-10-29 13:33:19.341755	\N
e1843173-5e85-49a1-ba6b-9b12cca469f9	34951266-6632-4c30-9d8b-ea2cfbca7912	f0e6aa74-b56a-496b-b3ca-ca32cfe31e6d	\N	2020-10-29 13:33:19.380811	2020-10-29 13:33:19.381558	2020-10-29 13:33:19.381558	\N
2479b413-d2f2-403c-8b36-2031e18a4323	46a34d38-caa7-4482-937e-f6f6a466b213	72135b47-561d-4428-abd7-ce81fb18343d	\N	2020-10-29 13:33:19.416745	2020-10-29 13:33:19.417517	2020-10-29 13:33:19.417517	\N
7367a68a-f01c-4df4-b7d8-b33088d9130e	2736c425-87cb-4b66-b21f-079696340d7a	f21b218e-465d-4d3b-ae47-d795e4dce063	\N	2020-10-29 13:33:19.447865	2020-10-29 13:33:19.449267	2020-10-29 13:33:19.449267	\N
b87a1b6c-1b25-498d-a255-8da4e5706aa2	214ac0da-8dd5-4b89-81e5-ca8d957de6c3	a32bf634-7a3e-4ed4-a582-a8837bbc1d8e	\N	2020-10-29 13:33:19.486804	2020-10-29 13:33:19.487483	2020-10-29 13:33:19.487483	\N
313e729b-db08-4383-b071-ab4ed5a6d140	a377be26-67c3-425f-abcf-5f06acf383f9	b9dd485e-4026-4b05-ab15-e15637450a99	\N	2020-10-29 13:33:19.517739	2020-10-29 13:33:19.518398	2020-10-29 13:33:19.518398	\N
250146da-fae7-4479-8ae3-b78721eebd45	150c0008-6477-4d2c-9da5-dd988d29222b	bc62f3f9-7185-482f-a071-fd19a69859fb	\N	2020-10-29 13:33:19.543378	2020-10-29 13:33:19.544021	2020-10-29 13:33:19.544021	\N
9a4151e5-db76-4d60-95ab-e95bc8ac8358	cbb86237-aae3-46e9-8a14-75fcfacd513f	625b5c44-4ffc-45d0-aa99-dca6b553f80d	\N	2020-10-29 13:33:19.570996	2020-10-29 13:33:19.571614	2020-10-29 13:33:19.571614	\N
c974028b-cf35-4337-b1be-98318400c69d	ced5bc1c-a708-4d8e-bca5-cba75db747af	5d1f456c-146f-4952-80b4-bddfbb41923d	\N	2020-10-29 13:33:19.596315	2020-10-29 13:33:19.596945	2020-10-29 13:33:19.596945	\N
3f3dd31b-b076-4bd0-8477-df339009239d	d4a1e37e-285e-4804-af95-c5263ed8ea16	377a1a0d-aa50-437b-a852-78f29ff569d8	\N	2020-10-29 13:33:19.622134	2020-10-29 13:33:19.622823	2020-10-29 13:33:19.622823	\N
519defb0-0ce3-4d9f-8205-d23326ea0a6e	73b35aff-05c1-4f6d-8a10-be823fbb598c	554412f1-9f39-4d08-a183-7eb70f7bcb18	\N	2020-10-29 13:33:19.647625	2020-10-29 13:33:19.648255	2020-10-29 13:33:19.648255	\N
5a4799c9-250f-4d8d-8aad-15a4a1677472	7d5169ee-dd91-49a2-905e-5f64b8c639d3	4592bfe0-e72d-46df-8a97-f074eaecc7fe	\N	2020-10-29 13:33:19.672979	2020-10-29 13:33:19.673633	2020-10-29 13:33:19.673633	\N
bf8771e0-f74c-4859-8b31-c6e462e50bfb	e9e726ca-0c17-4ef2-8af1-982792634943	670b7372-f05c-4cb6-a8b0-2e42cfa99208	\N	2020-10-29 13:33:19.698347	2020-10-29 13:33:19.698959	2020-10-29 13:33:19.698959	\N
5b0cb1a1-799f-47d6-b86f-c84e6f33bfb8	4f0a1a66-74d6-425f-bb84-48e04bdc9f9c	4146a53f-5166-4ad8-9387-bc6833d341ab	\N	2020-10-29 13:33:19.723508	2020-10-29 13:33:19.724139	2020-10-29 13:33:19.724139	\N
9328e882-6756-4860-847a-22f8eff715d8	f743b0a0-71a5-45bd-8545-0903002c9265	956fa2ed-8c30-4195-ab10-48acaaea9e43	\N	2020-10-29 13:33:19.748547	2020-10-29 13:33:19.749166	2020-10-29 13:33:19.749166	\N
59a8a40f-96f4-4998-8263-412f7abe8e6f	15182225-985a-426b-8d2c-5a3ab2626359	a036d331-2abe-4ce4-b4f0-811bccc1bea4	\N	2020-10-29 13:33:19.773221	2020-10-29 13:33:19.773906	2020-10-29 13:33:19.773906	\N
e587b0de-094f-48ae-ba1a-58ff782e4698	de8bc16b-ac92-47b1-bdd5-1b91cd7bc462	48aa57e0-bbcd-494a-a987-e471dbb4e793	\N	2020-10-29 13:33:19.794135	2020-10-29 13:33:19.794524	2020-10-29 13:33:19.794524	\N
c6ec95f9-0add-44bd-9b29-e93c23cb4378	a2b9ee00-9396-47b0-90a0-7fa7e3cf4ae6	46cd8f27-364c-449d-8327-581d1d789692	\N	2020-10-29 13:33:19.810571	2020-10-29 13:33:19.81092	2020-10-29 13:33:19.81092	\N
344908cb-c2b9-4d19-8245-ca3de5daadca	3b293c46-4542-47cd-9bdf-8ada8db0fcc1	7e566493-faae-4321-88ac-3143a14b9261	\N	2020-10-29 13:33:19.841281	2020-10-29 13:33:19.841756	2020-10-29 13:33:19.841756	\N
0076d205-7939-418f-a4db-d4f13c00f1b1	ffc39fe5-3bd4-43ff-b501-c0db3c6f85e2	5ed528dc-f265-46b0-9807-dc8a5cf40a15	\N	2020-10-29 13:33:19.864998	2020-10-29 13:33:19.865639	2020-10-29 13:33:19.865639	\N
9609855f-fc48-4ac9-a7f8-00a6c2e00152	871237e5-4e0c-4e43-b4a8-7b89584f8dac	da9c0415-cabc-406d-b47a-c553c62d3b95	\N	2020-10-29 13:33:19.891293	2020-10-29 13:33:19.891899	2020-10-29 13:33:19.891899	\N
21a70d5d-900f-4459-91fa-af48bede4fd6	9eb8131c-7a9e-49e0-97bb-939e34ad5837	592967e0-8e49-4609-af55-e9b38cbb7463	\N	2020-10-29 13:33:19.917395	2020-10-29 13:33:19.918157	2020-10-29 13:33:19.918157	\N
14b86dee-c1a6-4316-ba37-f6ed8609b02e	8959db00-c752-410a-8125-6adfd3ae2a41	923578c1-d1fa-44ed-949b-69c55eccf3a9	\N	2020-10-29 13:33:19.943591	2020-10-29 13:33:19.944262	2020-10-29 13:33:19.944262	\N
19b094b8-5958-4c2e-ba35-7594c29d3308	4734d4c7-35db-4844-aa87-ee342ea751bf	f921b59c-efa8-4328-8b0e-df7faf34907f	\N	2020-10-29 13:33:19.971361	2020-10-29 13:33:19.971966	2020-10-29 13:33:19.971966	\N
9c22fb46-ed59-49e7-8aad-01e521ce7d97	398b14f0-70b1-4277-989e-1f147a460caf	d52a7e95-c989-4da6-9e42-530b2a5f0d5a	\N	2020-10-29 13:33:19.994537	2020-10-29 13:33:19.9951	2020-10-29 13:33:19.9951	\N
e02f046b-a970-4a7d-9fce-971f6cdb77d7	91d59e93-0219-4dc4-83c9-1270538b1823	58833d5c-2a19-4259-b654-647db61c67a4	\N	2020-10-29 13:33:20.035328	2020-10-29 13:33:20.03694	2020-10-29 13:33:20.03694	\N
dd6d8f44-e2d1-479a-b861-3b7bbc695914	7832f506-50e0-4ab9-9208-82fd958c0ac8	4c50516b-768f-4030-8eb3-61b255f73697	\N	2020-10-29 13:33:20.09301	2020-10-29 13:33:20.094162	2020-10-29 13:33:20.094162	\N
76d9dfef-ba71-4687-b2cd-e3f4652e53af	ccacc3d5-c4d5-4626-9b4e-85a1799a3f67	8ad20b62-0fa9-4c3c-a066-2fd9359f1f84	\N	2020-10-29 13:33:20.116472	2020-10-29 13:33:20.116958	2020-10-29 13:33:20.116958	\N
2d3ed4ac-cbb3-4419-9945-e0432976fe3a	1f4383c7-3005-4fa8-bb2e-cfddf15dc9ed	092ed4a2-cf2b-426e-9f1a-97c173a4908b	\N	2020-10-29 13:33:20.13736	2020-10-29 13:33:20.137898	2020-10-29 13:33:20.137898	\N
9bf05ad3-d978-4c23-83e4-2da5c6d8dda4	13a390f1-93f4-4e79-b18c-d64175a8698e	411503ca-5091-4a56-b5bb-f5433cba378f	\N	2020-10-29 13:33:20.157961	2020-10-29 13:33:20.15847	2020-10-29 13:33:20.15847	\N
41c25d43-cecb-431e-ad27-4c279b87422c	a9857a91-a49c-4653-ae14-d9d5fef9ce80	3aaac8e8-805a-4b2c-9d5d-8b16a6dc90f5	\N	2020-10-29 13:33:20.178562	2020-10-29 13:33:20.179093	2020-10-29 13:33:20.179093	\N
e8b50c3a-e7c1-4b74-98af-3a81461ad08d	1113303b-6624-4a42-95e8-0eb907fc4ed5	36657f2c-c1be-444a-98c1-173f476146c4	\N	2020-10-29 13:33:20.198262	2020-10-29 13:33:20.198824	2020-10-29 13:33:20.198824	\N
13eb192d-0c70-40e8-b937-bc646c1efbf4	5c417336-23ae-47b8-81a8-ead6e44100fc	fd3108e7-7de8-4015-977b-8621efb130c2	\N	2020-10-29 13:33:20.218686	2020-10-29 13:33:20.219073	2020-10-29 13:33:20.219073	\N
c254b8c8-1c30-4ba9-8876-92e634e14d57	c5d0b96e-fbe8-4074-b0e5-a38f9ae7e0eb	28050ebb-9652-40c9-ba63-22feb33eb312	\N	2020-10-29 13:33:20.236997	2020-10-29 13:33:20.23734	2020-10-29 13:33:20.23734	\N
5a260ac5-1f63-4b40-a070-bfb328cfd382	685c45f7-0bab-48a6-8452-d0db3799960c	cce2a66d-c5e6-4d03-9d5c-09d8dd1931fd	\N	2020-10-29 13:33:20.253323	2020-10-29 13:33:20.253593	2020-10-29 13:33:20.253593	\N
c19be67f-0320-4a6f-bcd8-19ca09e4d55f	8fc3f06a-afca-4aff-9970-3b23de9e538d	e56e857b-6232-476a-a841-4bcbf64dc0f9	\N	2020-10-29 13:33:20.268095	2020-10-29 13:33:20.268381	2020-10-29 13:33:20.268381	\N
6634dcf8-6051-4aa3-9723-2d880111216d	297dc1df-6441-4857-a8b7-b617207d49a6	8c33cfbc-9f74-4b2e-a924-38b53ccf8871	\N	2020-10-29 13:33:20.28282	2020-10-29 13:33:20.28314	2020-10-29 13:33:20.28314	\N
f7a8842f-c630-4a72-be9a-4f95b1670b88	eb846b07-a15c-453a-a2c6-f6054acebb77	1dbc877c-2a7f-4d74-87f2-4847a578749e	\N	2020-10-29 13:33:20.297583	2020-10-29 13:33:20.297924	2020-10-29 13:33:20.297924	\N
e376923b-fb47-4d00-bc71-7ff6dc99d17b	bf2345ee-2d5d-4303-98bb-f00ce00c6b91	00f0a783-1ae4-425c-b2a7-ee59a6f3ca9e	\N	2020-10-29 13:33:20.312772	2020-10-29 13:33:20.31306	2020-10-29 13:33:20.31306	\N
a9409578-627d-4edb-97a1-e15754713c96	acd41b35-1641-45cf-ba6f-0eb9552adf08	64f3ad7f-cb3f-4c4f-81ff-ce904daa128d	\N	2020-10-29 13:33:20.329228	2020-10-29 13:33:20.32963	2020-10-29 13:33:20.32963	\N
b2c3e26d-2f52-4ead-aff4-99807c4a6615	b3ff8822-62c4-477b-a57d-ec1a6ea8de6f	e2aabc15-e462-47c6-b224-71f518d32d6c	\N	2020-10-29 13:33:20.349014	2020-10-29 13:33:20.349446	2020-10-29 13:33:20.349446	\N
7b073656-d481-4235-ae60-d976fe0dd22b	85d7e406-c214-400a-8cd8-ed23d54be974	ec6ec0f1-f63e-4d4e-b6cb-7960f2c5655f	\N	2020-10-29 13:33:20.368324	2020-10-29 13:33:20.368744	2020-10-29 13:33:20.368744	\N
d6663ca9-998e-4f84-9c10-835802d8b1ae	26673026-2ee9-43c5-aa3c-a127c11f0a3a	055b9518-5808-48f7-a6fd-3239fde1b2e5	\N	2020-10-29 13:33:20.387064	2020-10-29 13:33:20.387479	2020-10-29 13:33:20.387479	\N
ff168575-461a-4b97-97b9-6a7cc7686f6f	10156a6c-38d3-469b-8991-3de7c33c0ec1	ee0e7be3-fcb6-4c7d-b64c-84c5d206165d	\N	2020-10-29 13:33:20.403112	2020-10-29 13:33:20.403493	2020-10-29 13:33:20.403493	\N
718be983-0be3-4b09-9d30-df9530a90f61	da2cc00b-7a38-41e8-84e6-9cb2675414e2	519d58b5-042e-4999-9a41-85db6b493494	\N	2020-10-29 13:33:20.44899	2020-10-29 13:33:20.449743	2020-10-29 13:33:20.449743	\N
ae35b5af-cd4f-4f98-b311-3051b9927802	0f99978d-25f5-49ab-b6db-9747d7c52ff1	470bfd59-4b22-49af-90ec-fe7908acf37e	\N	2020-10-29 13:33:20.48298	2020-10-29 13:33:20.483997	2020-10-29 13:33:20.483997	\N
20b9e7f1-777c-4801-9669-a3dbf5684b40	13a1edf5-ff4b-4907-b6ed-00b3ea54c5a6	f8f47a74-0b97-4964-81f5-34209144cca1	\N	2020-10-29 13:33:20.521749	2020-10-29 13:33:20.522935	2020-10-29 13:33:20.522935	\N
be5da88d-bf3a-4e57-860d-27fd3faf3f05	5d2cc928-573b-49de-af9e-9e1d2db71c64	e7b9270c-dd2e-4ec5-b39f-1472a1d93f7c	\N	2020-10-29 13:33:20.551729	2020-10-29 13:33:20.552524	2020-10-29 13:33:20.552524	\N
12089d3d-8288-4828-b12d-447ac6b12a02	f36f5f14-b924-4d4f-928f-b0886e7efab7	e245267b-541a-4dfe-a35e-dc1a699d6133	\N	2020-10-29 13:33:20.586223	2020-10-29 13:33:20.586758	2020-10-29 13:33:20.586758	\N
a74e04f9-4ac4-4fb3-afbf-b8fb98c45389	319d291b-9c7f-4b01-a7b6-f7ba84916a40	6cab0f30-2a5d-494a-a6f1-43f3e26c727b	\N	2020-10-29 13:33:20.611584	2020-10-29 13:33:20.612089	2020-10-29 13:33:20.612089	\N
72c427ca-5bc7-4908-8c4e-4e25e31a2a75	ee71765a-2959-444c-8fef-7ef492ffed45	3b4b6771-67fb-4079-805e-7944cd2a799d	\N	2020-10-29 13:33:20.637199	2020-10-29 13:33:20.638681	2020-10-29 13:33:20.638681	\N
e0faa2cd-b6ce-4a95-b111-87b789338184	3da67365-62f9-4774-a9f5-e7d44df49ac0	0f10635a-ac96-4905-b31d-b40449e70c7a	\N	2020-10-29 13:33:20.667076	2020-10-29 13:33:20.667513	2020-10-29 13:33:20.667513	\N
5fc1f142-4780-486c-8e9c-03cd459d2830	2f2bb2d0-b5c5-4d44-9a2c-17c95b02ff2d	7cfec776-57ee-434a-82c7-9bd1e0fd0842	\N	2020-10-29 13:33:20.69394	2020-10-29 13:33:20.694416	2020-10-29 13:33:20.694416	\N
0c48e323-ca4f-4dc8-b5a6-038274acd995	0107c66a-eeb6-445b-aef4-01a6de6654c2	a13ce5d4-3119-403b-b8ad-5009ef5cfd9c	\N	2020-10-29 13:33:20.712849	2020-10-29 13:33:20.713134	2020-10-29 13:33:20.713134	\N
9d2187fb-d5a7-4d34-8361-efdecbb5f35c	b94a1a17-4a5f-4d56-8897-86dfb59339f6	5fa93060-a05f-445e-8863-28cfb5599b68	\N	2020-10-29 13:33:20.727374	2020-10-29 13:33:20.727649	2020-10-29 13:33:20.727649	\N
3166cec0-3fa4-4f64-b391-b2972b0123f0	3214357e-28f5-4e4b-b9ad-ebc2d0fc3997	3ca481b6-4ab5-4b1c-92ec-24f782e01a3c	\N	2020-10-29 13:33:20.741788	2020-10-29 13:33:20.742052	2020-10-29 13:33:20.742052	\N
735b849a-eb79-4548-9746-37898e05dd82	7b200c93-8a4a-4930-975c-2be4393d2118	ff86616d-91f1-4715-a25f-f6abb98214df	\N	2020-10-29 13:33:20.757757	2020-10-29 13:33:20.758153	2020-10-29 13:33:20.758153	\N
ba037c55-ad5c-48bd-9ae2-6cfbb5cb3630	419bb088-b9af-4e97-b41b-4e1f3b424126	573fa4f5-4100-483c-925d-8bd0c4519e78	\N	2020-10-29 13:33:20.799733	2020-10-29 13:33:20.801237	2020-10-29 13:33:20.801237	\N
83e99b98-725f-4157-819e-67e0e06f19a0	d8a2bb86-01fd-486a-8a2c-96861bfa341d	c397a9f2-4983-403c-ad34-c29a93115b5a	\N	2020-10-29 13:33:20.843956	2020-10-29 13:33:20.8446	2020-10-29 13:33:20.8446	\N
10fd4c8e-4f0e-413a-ab88-fd338a5313e9	128f0028-1988-4505-8629-4e104c23460e	4cd46fc1-b4a5-44bc-9a3b-4cf2eeea2a1d	\N	2020-10-29 13:33:20.864364	2020-10-29 13:33:20.864836	2020-10-29 13:33:20.864836	\N
2adfec78-72ad-4c5d-8d78-d97b63050840	614b7905-3569-4b88-aaa6-05d7a9668746	c3bc8dbb-dd26-444a-8ef1-1af46cc74246	\N	2020-10-29 13:33:20.882875	2020-10-29 13:33:20.883354	2020-10-29 13:33:20.883354	\N
6260f497-3d74-496d-afae-7512a9dbb5dc	bd9fe0b3-043f-4f94-b17d-ae4a13fd9fbc	df831f44-fa0c-4066-9ce5-b44852a42122	\N	2020-10-29 13:33:20.906143	2020-10-29 13:33:20.906582	2020-10-29 13:33:20.906582	\N
26be57ef-bd34-4d13-b9a8-3985a09dd201	ac9132af-65e2-48b8-8efe-146feea6c3cc	a82e3b86-206d-45fa-a964-f3a36edb8d12	\N	2020-10-29 13:33:20.924217	2020-10-29 13:33:20.924629	2020-10-29 13:33:20.924629	\N
204bfaac-348b-402d-a607-c8a7e4bd8de1	d05c44d3-5715-4fd8-a712-d1b960748f08	0b37b573-dd6a-4da2-9101-528bc4e84b6f	\N	2020-10-29 13:33:20.955821	2020-10-29 13:33:20.956979	2020-10-29 13:33:20.956979	\N
05d61f33-f938-4907-a242-1609a0653a7e	21919b7f-bd80-48cd-8ba8-46b8ea1057ee	f916e428-df94-484c-a913-cae8a1a0629a	\N	2020-10-29 13:33:20.981992	2020-10-29 13:33:20.982433	2020-10-29 13:33:20.982433	\N
b8549e5c-61ee-4959-b64e-fdd8c81f5d59	f984dbd4-3ab0-412f-aa29-750239cc5e0d	0d149210-4782-4d55-8d98-2050dcdf76f8	\N	2020-10-29 13:33:21.000408	2020-10-29 13:33:21.000901	2020-10-29 13:33:21.000901	\N
8c29ec78-6b8a-463f-a8e9-cf7bdac95424	494c94a4-5b42-4eca-9d66-c01257306ca8	4aa18e08-2c0d-4ba0-936a-04a6f966c9b1	\N	2020-10-29 13:33:21.022905	2020-10-29 13:33:21.023403	2020-10-29 13:33:21.023403	\N
fca1a266-ed0a-4d19-a1d2-1d35b4b12b8a	0bb527f1-1be8-4bbe-8f26-0a26b7ff9ca3	bbf3d9f7-211a-48df-b808-d26e212e05e0	\N	2020-10-29 13:33:21.052399	2020-10-29 13:33:21.052813	2020-10-29 13:33:21.052813	\N
8cbfd1bd-9e56-4de9-a401-25f2dc88dd43	80fcec7a-decb-4196-aa1a-a068e65eea9d	eb8b0e84-2578-41ca-b8f6-102e07403aac	\N	2020-10-29 13:33:21.071574	2020-10-29 13:33:21.072094	2020-10-29 13:33:21.072094	\N
4c81d158-1ebf-436c-acd9-e190410e5459	467b5ceb-74e6-4740-9121-39a1a3dbb105	42218a7a-1de6-4ca8-bdd1-1f7af2dfaeb4	\N	2020-10-29 13:33:21.097031	2020-10-29 13:33:21.097501	2020-10-29 13:33:21.097501	\N
63de2f2e-2a6b-4d2d-a434-48b641c4a9da	2a833812-65e4-48b5-94c4-292ad56fb75e	dc3649e5-2f11-41c9-91b7-502344cfbc87	\N	2020-10-29 13:33:21.116265	2020-10-29 13:33:21.11664	2020-10-29 13:33:21.11664	\N
63611e34-1274-4cc8-92bd-2a3643854eed	69257ce3-5416-4cb6-ba6d-9e5e19f326bb	d9d390ce-16e5-403a-92cc-9a27619a1193	\N	2020-10-29 13:33:21.138327	2020-10-29 13:33:21.13886	2020-10-29 13:33:21.13886	\N
28b4d9ee-ed6b-44a5-83c7-e5d9063d0233	70565ca6-4b22-4707-96c1-539d13d31d3f	3ee7b7a9-0f6f-4d17-a8e9-16abe5298035	\N	2020-10-29 13:33:21.160309	2020-10-29 13:33:21.160655	2020-10-29 13:33:21.160655	\N
c58b91dc-1862-4ec2-99db-b24e2780a11f	549fb0a2-83d7-4571-a701-b37a377a16e3	1418b03c-dead-48aa-895b-fdd63f125d16	\N	2020-10-29 13:33:21.176344	2020-10-29 13:33:21.176683	2020-10-29 13:33:21.176683	\N
b6c4b9b0-2e25-4d01-92b2-965ce19b7ef7	d08e37eb-3281-410c-a23b-e63e4520bff8	1560ae8a-2769-472c-9965-abb21d746780	\N	2020-10-29 13:33:21.19214	2020-10-29 13:33:21.192573	2020-10-29 13:33:21.192573	\N
2a57ad5b-cc65-4616-bd9c-37aba6dd3392	6564e10e-daf6-415e-ab30-ad8a212b1b58	729cd792-5d08-4b7d-9706-07a546088a80	\N	2020-10-29 13:33:21.212853	2020-10-29 13:33:21.213195	2020-10-29 13:33:21.213195	\N
66fc735d-e23d-4001-aa68-3d60cf63259a	2e2f7299-cec4-4691-befc-e6c7370b68ff	aba7afb9-5f97-4d7b-8c8f-e9f9996ca170	\N	2020-10-29 13:33:21.229151	2020-10-29 13:33:21.229502	2020-10-29 13:33:21.229502	\N
5d732d41-1d11-4020-89c8-9f53d8a10fe4	3007c40a-4457-4e0c-8116-d6c1bc8a6875	2ed2785e-4022-405a-bdb3-aaaab91b59d7	\N	2020-10-29 13:33:21.245308	2020-10-29 13:33:21.245665	2020-10-29 13:33:21.245665	\N
376d674b-adf6-40ce-afd4-2658780a7c5d	4ce2fc92-3b08-477c-b2e5-57efea3d5f46	2f32f6c6-de5b-4651-a78e-04f293601fed	\N	2020-10-29 13:33:21.260983	2020-10-29 13:33:21.261397	2020-10-29 13:33:21.261397	\N
c16a54bf-5d69-4764-8f86-c7f218ab5a40	0953cc7e-cbdb-42ad-9f97-31d8b33fe33d	85525b77-0800-4e59-88e4-1d843e78bc6e	\N	2020-10-29 13:33:21.276721	2020-10-29 13:33:21.277144	2020-10-29 13:33:21.277144	\N
7e4e4c31-8700-43d2-a31f-ffd22dc75860	0179f5f8-2b1e-4959-b824-1e06271eb6e0	6c6d98ab-66c1-45be-9fcb-caef7f7a21cf	\N	2020-10-29 13:33:21.293219	2020-10-29 13:33:21.29366	2020-10-29 13:33:21.29366	\N
3740736c-be08-4ea0-b8fa-546ee59cbc57	e200b786-3f61-46da-a0d2-b74bbcecd625	b4021eec-e5a6-4598-8c97-f57e2d7ccbd7	\N	2020-10-29 13:33:21.309316	2020-10-29 13:33:21.309631	2020-10-29 13:33:21.309631	\N
26e50a0a-9662-41bb-b38b-60d50aa10e97	5e11d21d-b90c-4486-b75f-a5986d85f824	b8ea3f73-31b7-45f1-981b-0fa1c354791f	\N	2020-10-29 13:33:21.32648	2020-10-29 13:33:21.328017	2020-10-29 13:33:21.328017	\N
cf3e4392-c72c-4131-8b79-88482b061792	c98fe917-3f11-452d-a504-073a3221dbd5	3ee1339f-f944-462f-ae7b-f9ee1599dd41	\N	2020-10-29 13:33:21.368234	2020-10-29 13:33:21.368736	2020-10-29 13:33:21.368736	\N
3ab54ea0-121a-438f-bc87-c2709e662409	dc2e6099-2ff2-49f3-a95a-18cdda7e7470	62b58faa-c7bd-4429-bf32-a937a8ac3bc9	\N	2020-10-29 13:33:21.387519	2020-10-29 13:33:21.387968	2020-10-29 13:33:21.387968	\N
b663622b-6403-4696-b6a3-9a781faf84e9	22b893a1-4cc4-49db-bca0-01619d3f85a8	45920f24-f224-4014-9d90-6ebf5dfa9d8f	\N	2020-10-29 13:33:21.418673	2020-10-29 13:33:21.420293	2020-10-29 13:33:21.420293	\N
5403f6ee-3517-4485-adf4-fc2e2b9bad3d	882a3256-a965-4b38-8b4b-a2e55236e272	30a28261-88ea-492d-a5b4-d2056070e2f4	\N	2020-10-29 13:33:21.453395	2020-10-29 13:33:21.453951	2020-10-29 13:33:21.453951	\N
be288cff-9ba8-4e0e-9689-05ae4ba18aeb	ce45f0d2-9953-41b1-9c6e-0a2ee804637b	eb1f94ad-59d9-46bd-a654-9a7a0b401b50	\N	2020-10-29 13:33:21.474456	2020-10-29 13:33:21.474972	2020-10-29 13:33:21.474972	\N
8055069a-75d2-4893-8d14-9a43543dddc7	56c89a1b-5941-414b-a969-f7c96593aaca	030173ab-82be-44ae-9a43-f398f32cf426	\N	2020-10-29 13:33:21.495185	2020-10-29 13:33:21.495713	2020-10-29 13:33:21.495713	\N
f5c4eb97-4cb6-4dbd-bf84-8eab7078ee83	c05ea25d-3c6c-469d-9c96-3d2dc67d8efb	6d6afa9c-6b21-4e3c-937c-742a5c345804	\N	2020-10-29 13:33:21.519382	2020-10-29 13:33:21.5199	2020-10-29 13:33:21.5199	\N
dbd4580b-67bb-456b-995a-652a40f34424	42b864f1-333b-4b65-b0d9-13dbf80e66ef	dbd46855-bf17-44f8-9d28-43c5f6bb4723	\N	2020-10-29 13:33:21.539711	2020-10-29 13:33:21.540151	2020-10-29 13:33:21.540151	\N
2cbf5072-d406-4018-9c10-5e804b06fb91	360a139d-b441-4324-803d-97c88168a53a	5e9e054a-6043-4b4b-8323-d2b7d3ad8d31	\N	2020-10-29 13:33:21.559687	2020-10-29 13:33:21.560159	2020-10-29 13:33:21.560159	\N
fd9c4515-64b8-4aca-a532-51bc5bbfab60	60c93106-7e18-4442-b096-bc7050d76727	ba16cd9f-a2b1-443b-818a-e771cea9f2e0	\N	2020-10-29 13:33:21.580286	2020-10-29 13:33:21.580798	2020-10-29 13:33:21.580798	\N
a61d39b5-3d80-46fa-9396-f2ee51e5dc41	53fd1dcf-584d-4559-81d6-e0cbdef2de11	d76a6b42-c85e-4449-ae5d-c61e7e128856	\N	2020-10-29 13:33:21.601083	2020-10-29 13:33:21.601584	2020-10-29 13:33:21.601584	\N
c31c032d-b1ee-405e-90c9-f48120739d48	291503f2-c751-403b-8b97-69e65e0f371c	5b5aa08d-27ec-45c1-9c2a-42b7cf40f3a5	\N	2020-10-29 13:33:21.626006	2020-10-29 13:33:21.626493	2020-10-29 13:33:21.626493	\N
c96f5d0d-01bd-458f-821c-e493e1e05aac	20135e56-0cc9-40c8-8acf-2a9a06061230	4104b3d2-5e48-4678-bc36-5530de6081d8	\N	2020-10-29 13:33:21.658231	2020-10-29 13:33:21.659818	2020-10-29 13:33:21.659818	\N
cd4f75d6-27f2-4476-8b53-69321fbd4799	d48be149-cfe3-449b-b661-0f9263e576b2	51268410-3a7e-4f84-a7b1-b78aa4c1c087	\N	2020-10-29 13:33:21.691965	2020-10-29 13:33:21.692509	2020-10-29 13:33:21.692509	\N
3bd9b449-efe7-425a-ae8b-216496a9f3a5	e750a29f-8a92-4331-899e-cb27b948d888	630f7ea2-d57e-4d5b-87f4-3c816c51f73f	\N	2020-10-29 13:33:21.717545	2020-10-29 13:33:21.718096	2020-10-29 13:33:21.718096	\N
26a97be2-f103-431b-9dab-8dbc5ddf2db6	1157270c-5129-4ca4-a488-1fa35fd490a8	9091211f-1547-42f5-b08c-f6d1688c2304	\N	2020-10-29 13:33:21.738713	2020-10-29 13:33:21.739229	2020-10-29 13:33:21.739229	\N
38441355-cfc7-483c-a3b5-560c009bd312	96b9ac6d-5b56-4ffc-93e5-9a3ddadc2a35	d2114805-8b70-4899-86d9-92e27e551393	\N	2020-10-29 13:33:21.761084	2020-10-29 13:33:21.762513	2020-10-29 13:33:21.762513	\N
9332ab24-6b40-48ef-b390-800dc43d7472	e05b396b-b5ea-40ac-b332-08b8194cdb28	32c4ee2f-b8bd-4ff9-8130-e962d5329028	\N	2020-10-29 13:33:21.804575	2020-10-29 13:33:21.805586	2020-10-29 13:33:21.805586	\N
cffbead8-3cf3-4900-8e43-aa7c7641a64b	f32814d9-06fe-413a-a919-bc3361c506d5	85271509-7274-4825-bbd5-209af3918b39	\N	2020-10-29 13:33:21.842394	2020-10-29 13:33:21.843413	2020-10-29 13:33:21.843413	\N
992ed6ca-6308-4a1b-94de-7f33cd15df18	05856844-c16e-4e50-adee-7a36ffdc3d4d	bc001262-28af-4e41-a4fb-666e7c04e908	\N	2020-10-29 13:33:21.872395	2020-10-29 13:33:21.872983	2020-10-29 13:33:21.872983	\N
a0771a5c-6b42-4329-bf14-a42df09817a6	b43f3a6e-b497-4f91-9953-b032ff516e6e	2387d35a-5a36-4ca0-b19a-518417924374	\N	2020-10-29 13:33:21.894619	2020-10-29 13:33:21.895163	2020-10-29 13:33:21.895163	\N
05db3fcd-38b7-47af-a73d-7680ede042da	ea1db596-7c5f-4321-ac8b-5915e20656fb	d8fe2025-31fa-4d8c-88db-890bc2fa79b9	\N	2020-10-29 13:33:21.917161	2020-10-29 13:33:21.917727	2020-10-29 13:33:21.917727	\N
d258973e-82da-4285-b36e-ed8d88ccaa45	efb31859-766c-4a23-8c20-6e00f33148e0	a21fecd1-5c4d-41cd-869c-b0412ff7093b	\N	2020-10-29 13:33:21.939292	2020-10-29 13:33:21.939874	2020-10-29 13:33:21.939874	\N
59cbba4e-b6ad-44c0-ad99-ac62410d32a4	011c3ba7-fdd7-462d-a479-30d3f7b0071e	eb605ee8-2b82-4ed6-a440-7a48b168463c	\N	2020-10-29 13:33:21.967194	2020-10-29 13:33:21.967826	2020-10-29 13:33:21.967826	\N
4e41e0b9-b845-429a-847f-b05d0dab902e	690d1521-7b52-4500-883d-37a5c053bd67	14ea1d8e-7b16-4a60-956c-5119da491179	\N	2020-10-29 13:33:21.990332	2020-10-29 13:33:21.99094	2020-10-29 13:33:21.99094	\N
540be1af-80ea-4d3f-95d9-c56c7d2790ab	f3b438c5-e446-45de-b1da-01ea40649b12	94aa1447-d880-45bf-b46c-0b65bcc9bd53	\N	2020-10-29 13:33:22.013365	2020-10-29 13:33:22.013953	2020-10-29 13:33:22.013953	\N
2ca7b064-7f8c-427d-a190-bd4679ef8556	7a4eec2e-0d21-4a0e-935d-48d8456bc587	e7a02bbe-e0b1-4a1e-96ce-fc5ee1422c9f	\N	2020-10-29 13:33:22.044317	2020-10-29 13:33:22.044817	2020-10-29 13:33:22.044817	\N
aa8e7dfb-9029-4485-b7df-b5330c6dc21f	560a57f4-0453-4cea-b407-d75e65f74f22	c193fabb-749a-4a84-af8d-6a630ab82b89	\N	2020-10-29 13:33:22.079867	2020-10-29 13:33:22.080882	2020-10-29 13:33:22.080882	\N
f7bde276-0da7-4067-af05-f192e5c675fe	8857a7d7-0854-4e62-8d8c-f97c3cb5c00e	cc1ae4e7-33a7-4436-8c3f-5af7ea4e5d11	\N	2020-10-29 13:33:22.110747	2020-10-29 13:33:22.11132	2020-10-29 13:33:22.11132	\N
2e0b65ef-bd88-456a-a8af-f46887004d2c	dec13c23-66ab-4d90-b40c-2cef4defdb8b	0ee39c0b-91b7-4ac6-8a3a-8b34eacf77bd	\N	2020-10-29 13:33:22.132247	2020-10-29 13:33:22.132717	2020-10-29 13:33:22.132717	\N
51c9ac4f-ffef-49ee-a1d3-2463397399e7	97541fca-0de2-432d-a812-275530b6f3f1	dda670af-ca8a-4268-b471-ede2241f6650	\N	2020-10-29 13:33:22.152275	2020-10-29 13:33:22.152802	2020-10-29 13:33:22.152802	\N
7d309c1e-351e-4ae9-8dc0-90ff6ea2aa7b	6e032409-884e-4fb0-bde1-997b855f86f2	ec023395-e306-43c5-9667-b93bbe09218a	\N	2020-10-29 13:33:22.176859	2020-10-29 13:33:22.177403	2020-10-29 13:33:22.177403	\N
10eefd53-c937-448e-917e-0123580a6ea0	767e1aba-99a4-4a9d-9fae-db0c9e5a2a2d	ee33caa5-2854-4d0b-90d0-213dece134d8	\N	2020-10-29 13:33:22.197552	2020-10-29 13:33:22.198004	2020-10-29 13:33:22.198004	\N
7732a28b-b606-4e53-a9cf-5fe194ab9c6a	ee9531a3-1af4-4ea8-b955-e41a02fbfafe	f0413d70-2dc3-4470-86ca-c25f331d5c2f	\N	2020-10-29 13:33:22.217659	2020-10-29 13:33:22.218202	2020-10-29 13:33:22.218202	\N
b336c484-2e8d-470c-88e8-45efacec8822	3ca7144a-e2a6-4381-bb78-579ab865d3e8	492c49c6-a13c-4466-a365-1ff74891f6e0	\N	2020-10-29 13:33:22.238442	2020-10-29 13:33:22.238978	2020-10-29 13:33:22.238978	\N
9ca20d12-7cd9-48e3-8454-4794d1471b18	45fa4f37-c77f-4110-be51-8504391df5c9	b35d51cb-d5f8-4457-9e8f-6b2985c4df44	\N	2020-10-29 13:33:22.258456	2020-10-29 13:33:22.258905	2020-10-29 13:33:22.258905	\N
9363df5c-ed33-4546-84b0-3005a825482d	7bfc901c-7e35-4367-9a42-c7bf6c814bcd	77ccaa3d-39f8-4e13-aca0-f328497d39c4	\N	2020-10-29 13:33:22.278735	2020-10-29 13:33:22.279259	2020-10-29 13:33:22.279259	\N
3f22561f-cd4d-42d8-9b45-28946d015f2b	34942033-50a8-4887-a671-69f0aadb9d27	4d273888-ab7d-4bc8-8617-0c786d27d32c	\N	2020-10-29 13:33:22.303635	2020-10-29 13:33:22.304105	2020-10-29 13:33:22.304105	\N
40b63bf6-5a14-46c3-bfd1-c26973115455	2fadc02e-913a-414b-a87f-263c2433c6f1	1d3f79df-78c5-41bc-a923-8f4ac0c34fb6	\N	2020-10-29 13:33:22.326283	2020-10-29 13:33:22.326806	2020-10-29 13:33:22.326806	\N
99391871-ef8e-4dc4-91a9-afaf88f40374	cb318ab9-1bc6-4d02-9c1f-46b8b673d084	3b9cbd67-3073-461b-984a-1711b5c6bc73	\N	2020-10-29 13:33:22.346495	2020-10-29 13:33:22.347934	2020-10-29 13:33:22.347934	\N
88f18c70-f4ce-4cba-bc56-190f8c78e56d	f6bab140-184b-49d7-a91a-bd0720799480	4856be18-7fd2-4df9-b216-c5da68744c74	\N	2020-10-29 13:33:22.383803	2020-10-29 13:33:22.38439	2020-10-29 13:33:22.38439	\N
cf2a951f-0699-4dd5-a126-d85cb84342b1	74822108-e5a9-4f3e-a1a1-4c828297d010	e8f1f614-f8a4-43e7-a03a-07e278c0495c	\N	2020-10-29 13:33:22.407539	2020-10-29 13:33:22.408075	2020-10-29 13:33:22.408075	\N
169fdd6c-84c7-41ab-a0c3-3abf1eef6b45	165020e8-5dd5-454e-8c22-55ac4abacc72	40f71bfc-e804-488e-b88b-3a7eaa493f54	\N	2020-10-29 13:33:22.435196	2020-10-29 13:33:22.435796	2020-10-29 13:33:22.435796	\N
9c2fe39d-7219-4f66-b8dc-1fad53934c70	09df4b91-b8a0-4a06-ad76-b0886849467a	ca5c07df-275e-43ca-a3fa-0e6fe7b86ff0	\N	2020-10-29 13:33:22.458362	2020-10-29 13:33:22.458953	2020-10-29 13:33:22.458953	\N
188895d9-ef96-4d08-ba6f-998173c008d8	a9a5dd7e-fc87-4602-8d33-af23a4ae1295	6be32111-1a17-487c-a043-e855fd8227a4	\N	2020-10-29 13:33:22.48109	2020-10-29 13:33:22.481687	2020-10-29 13:33:22.481687	\N
d22442d8-fc8a-48df-a690-a1474d80c0a6	5ac8659e-7d6a-43c7-a3f4-b12589599b24	478150c9-6e0c-4e43-9e29-ebcc3fbb0ed6	\N	2020-10-29 13:33:22.504387	2020-10-29 13:33:22.505022	2020-10-29 13:33:22.505022	\N
b8a62e6d-260a-4356-9282-856b54e065a1	e56f777b-5ae0-4d44-b32a-f7459616f04c	4eaf933f-aac2-44d2-b6e3-227abb6be846	\N	2020-10-29 13:33:22.526553	2020-10-29 13:33:22.526949	2020-10-29 13:33:22.526949	\N
64e7b4ee-d732-4d33-8b51-d7089ded9a17	b86feea2-e44e-434b-9e30-9114c3ad10ee	10135158-e789-4ed7-9044-15edb8f27cab	\N	2020-10-29 13:33:22.543922	2020-10-29 13:33:22.544302	2020-10-29 13:33:22.544302	\N
dcd9352b-32de-4db3-8de1-3afcd18711dd	55dcb700-5b95-49d3-b07d-1be71b432938	8d480b0f-2525-47fa-9f80-f91786908a3e	\N	2020-10-29 13:33:22.566348	2020-10-29 13:33:22.567024	2020-10-29 13:33:22.567024	\N
b4737bf7-dee2-4c31-b390-cea1d6fdf813	6ab38a22-0100-48d1-b28c-9a9bd1cce4cc	5ac4d7f5-52fa-48a3-a693-9f0bc368dad6	\N	2020-10-29 13:33:22.587111	2020-10-29 13:33:22.5876	2020-10-29 13:33:22.5876	\N
db5528b7-1797-41b8-a18a-78efc511773f	31103147-2d07-436b-9b0a-f77d75d399a7	62f8a278-0779-46d2-8056-f2b11ceba2da	\N	2020-10-29 13:33:22.605831	2020-10-29 13:33:22.606228	2020-10-29 13:33:22.606228	\N
b0332340-8d33-4717-903f-15d9c83585ff	e2c3f4e7-6c5f-4c18-b1f7-c5ca0cce89ba	b6437356-9b02-4499-8cea-bcf5b1b2234e	\N	2020-10-29 13:33:22.624438	2020-10-29 13:33:22.624912	2020-10-29 13:33:22.624912	\N
6c1d3b32-b980-4e4e-a9c2-ddcbcc8706d3	a8ad2bd0-086f-4d97-b214-add8aa987214	5cc51c27-7afe-47d9-8892-d8e2847f32d7	\N	2020-10-29 13:33:22.643221	2020-10-29 13:33:22.643702	2020-10-29 13:33:22.643702	\N
a649fefa-31d3-40f9-8ae5-89dac1e28971	a2bfa22a-fa60-44d5-939b-779b4adb7593	8730793f-18bf-42df-b53b-710f6472b5c7	\N	2020-10-29 13:33:22.662352	2020-10-29 13:33:22.662783	2020-10-29 13:33:22.662783	\N
2977e724-c500-4389-b771-78d55c4bf905	ab98a496-cea0-438f-a221-3fc61a1fb1f5	211a9552-6b8c-419d-8467-83db49e8ddc8	\N	2020-10-29 13:33:22.701205	2020-10-29 13:33:22.702729	2020-10-29 13:33:22.702729	\N
46ffee14-dcab-4c77-84c6-35855097d9bb	bc4e3b72-40b5-4293-ad84-dc118bc911e9	0e22570b-b9af-4533-bd96-0e363679c945	\N	2020-10-29 13:33:22.729824	2020-10-29 13:33:22.730394	2020-10-29 13:33:22.730394	\N
94a91057-034c-435b-b01d-8f6fad4f239c	b133f604-5dbf-4532-85b1-adb404fb60da	5d552dfa-f89a-4027-a363-f1b1d515b820	\N	2020-10-29 13:33:22.749942	2020-10-29 13:33:22.750392	2020-10-29 13:33:22.750392	\N
f1fd61c5-5359-42d2-9663-d84ce720fb2e	2f46c09a-a1c4-43ec-9cca-fdd66b0a95d6	e498dca6-bf17-44bc-9139-3ad5cfaca753	\N	2020-10-29 13:33:22.770581	2020-10-29 13:33:22.771115	2020-10-29 13:33:22.771115	\N
79d79d29-a977-4418-815a-98d680c172ce	9b6f4421-4e3a-44de-bcaa-ec09f835ad09	9fd3b7f1-fb1c-4c27-acb0-1c328a6e0065	\N	2020-10-29 13:33:22.790986	2020-10-29 13:33:22.791524	2020-10-29 13:33:22.791524	\N
8555f60b-4b9a-49b7-a605-e4882090e21d	d4672b38-f816-4071-9223-5511ec9e7531	7caf571d-90f5-4dfc-8410-11ecd36a46a0	\N	2020-10-29 13:33:22.814398	2020-10-29 13:33:22.814951	2020-10-29 13:33:22.814951	\N
b9afa337-d438-4602-a9a1-54a31c78dca8	c9c57b51-92b8-46c9-8f7a-7997f266a880	0d4f5511-0a1f-40ef-b7e3-dfaf611bfb66	\N	2020-10-29 13:33:22.839253	2020-10-29 13:33:22.839716	2020-10-29 13:33:22.839716	\N
3bd4f995-4df0-4570-b270-561a8bdbfc11	a52afd23-3110-4fda-b102-1453bc6aaace	f9a415db-2068-4e75-8ef7-4d89f86e7a61	\N	2020-10-29 13:33:22.861164	2020-10-29 13:33:22.861686	2020-10-29 13:33:22.861686	\N
d49ba998-4de4-4c84-bcbc-4667726afb89	7608d317-8d4d-415f-9780-48c1073f17d6	0691a5a6-d5d8-4890-afc1-6c930f8de5b7	\N	2020-10-29 13:33:22.904031	2020-10-29 13:33:22.90473	2020-10-29 13:33:22.90473	\N
6351df7c-3c95-44c9-afaa-937cbe2f1caf	cd259949-2a3b-4b4f-ae67-10073c3cdabe	5cd482ae-f03a-47d0-be49-0546142a54e5	\N	2020-10-29 13:33:22.935603	2020-10-29 13:33:22.936281	2020-10-29 13:33:22.936281	\N
20da5c4d-b1f5-4605-a82d-79a0fa043178	91571c39-c843-4ece-b71f-42ec8ba81c52	eb67d4b7-8bb1-4101-806c-18f4f8f97fc4	\N	2020-10-29 13:33:22.970931	2020-10-29 13:33:22.971757	2020-10-29 13:33:22.971757	\N
c94cb78a-7568-47c3-be17-511fe50d3f2d	7ca63d7b-93e6-4b44-a28b-d0d627268cfd	d02ae872-0768-4d0d-814f-90d3d131bef1	\N	2020-10-29 13:33:22.994551	2020-10-29 13:33:22.995007	2020-10-29 13:33:22.995007	\N
f0969c8a-053a-4f2e-beef-ecaf6a2cdf9b	150f501e-fadf-4e56-bc94-338bd3028352	103512a5-8595-4528-b859-210a5021d531	\N	2020-10-29 13:33:23.012206	2020-10-29 13:33:23.012662	2020-10-29 13:33:23.012662	\N
14e73b21-254d-4bb9-a5fe-5ad14f873cae	022033c1-39c0-4c57-ac76-39a2995db7e8	00b3b85f-ae65-48c2-a5b9-713929f41251	\N	2020-10-29 13:33:23.030339	2020-10-29 13:33:23.03092	2020-10-29 13:33:23.03092	\N
16c107cf-eb0a-47cd-a0fc-701b01097ea9	c59f7383-59cb-4941-9fbc-29d0083dbca8	5e6cf422-1697-4fb7-9612-92e00cbc9c70	\N	2020-10-29 13:33:23.049708	2020-10-29 13:33:23.050173	2020-10-29 13:33:23.050173	\N
7469b998-007e-4328-8e5e-c60bd9afe74c	15753fb5-bf53-4482-a20f-81669bb11b1c	22890874-16a4-4136-91bd-71e88a822d1c	\N	2020-10-29 13:33:23.071561	2020-10-29 13:33:23.073113	2020-10-29 13:33:23.073113	\N
1bc6e8f2-1746-4224-961a-2831c600b413	ab1d3fe9-ae29-466c-9a5f-d6af9f83ffbe	21ad2ac9-3441-47f5-bc42-90ea910ef3be	\N	2020-10-29 13:33:23.124565	2020-10-29 13:33:23.125471	2020-10-29 13:33:23.125471	\N
55cae941-056f-4375-b992-f16c9f99620a	29580306-e06b-4556-8b69-31e27c5f3b2b	2bd75a7e-dec8-41a5-af02-cf9f3ea17ed6	\N	2020-10-29 13:33:23.154677	2020-10-29 13:33:23.155212	2020-10-29 13:33:23.155212	\N
ee6d979e-e08c-4e7e-8369-22b669a175dc	33c6bc95-6125-4fb6-943c-31912b12261d	b25af9fa-ebbc-4b57-980a-afe3458a2d54	\N	2020-10-29 13:33:23.178177	2020-10-29 13:33:23.178719	2020-10-29 13:33:23.178719	\N
ae24d0e8-a40b-4b41-b5aa-0c1418a782b4	988d2866-6f9a-4301-a5a5-7453269cae5e	3d184ce1-87af-4c86-bec9-d88904d3d622	\N	2020-10-29 13:33:23.20055	2020-10-29 13:33:23.201135	2020-10-29 13:33:23.201135	\N
4fd84e2c-13b8-4463-9cac-ce00a5c91e04	5bf02cc5-0a09-43e9-b840-7f44663294a4	4daaf11c-36e0-4339-ace8-f57f33cac27b	\N	2020-10-29 13:33:23.22248	2020-10-29 13:33:23.223096	2020-10-29 13:33:23.223096	\N
fa0aab79-f7b0-4181-a6af-ff4b1a6fa751	2251ea8d-0021-4089-aadf-3a883be2f433	9b18e490-806c-4ce5-b272-99f53c63f49f	\N	2020-10-29 13:33:23.244866	2020-10-29 13:33:23.245383	2020-10-29 13:33:23.245383	\N
c712792f-0955-4568-9321-71cadeff3821	1c621586-39b8-4701-9508-6d048eff5095	4ac59333-587c-4d6b-b371-1e6472a1b6b5	\N	2020-10-29 13:33:23.26792	2020-10-29 13:33:23.268504	2020-10-29 13:33:23.268504	\N
f1cfd6ad-b1fe-46f3-b94b-29683cbccf7d	f2bad979-52ab-4dda-bd32-fdfbfb90c233	f5d68b40-ff74-4491-bd11-39f87aa1b6ae	\N	2020-10-29 13:33:23.292683	2020-10-29 13:33:23.293314	2020-10-29 13:33:23.293314	\N
85d58cee-cd56-45f0-93a1-a8fdae338100	cb97b34e-7b91-4f68-af46-53ed7b8526c2	df0fedb2-e489-438f-8109-53f3e86e517d	\N	2020-10-29 13:33:23.317302	2020-10-29 13:33:23.31798	2020-10-29 13:33:23.31798	\N
ab27835e-aca4-42bf-98b6-5c477d3fd8cb	b7be0b1f-1794-44d4-bf95-4cbbfbf5d94f	b1c80616-e5b2-42b1-b8ff-778904736860	\N	2020-10-29 13:33:23.340827	2020-10-29 13:33:23.341276	2020-10-29 13:33:23.341276	\N
cad6cc0b-fc2e-465c-87bc-6dc06254e020	2cce1928-5d2d-4119-bb59-78000a2deec9	e4d48892-8970-41ca-adb0-ee988bd61bdd	\N	2020-10-29 13:33:23.359144	2020-10-29 13:33:23.359542	2020-10-29 13:33:23.359542	\N
e4f4db4f-b69e-4420-9518-c547d31604bc	564b1620-1f0f-452f-b72b-3b2d7d86a906	4f97ee10-706a-4c92-8160-c93cdd5815ce	\N	2020-10-29 13:33:23.377324	2020-10-29 13:33:23.377662	2020-10-29 13:33:23.377662	\N
febfeff2-b569-43d0-9c1c-465dda97f111	45d4a693-d742-4526-93ee-6bd5cd6e3733	c38e4c8b-959d-4f7a-afa0-3c953f9169fa	\N	2020-10-29 13:33:23.39428	2020-10-29 13:33:23.39463	2020-10-29 13:33:23.39463	\N
a49d986a-ec0f-4112-97c8-140f88990668	11349229-a429-4419-8642-eb0468407bda	d2f18240-24ab-4ddd-8a74-49676ebfb5b3	\N	2020-10-29 13:33:23.411021	2020-10-29 13:33:23.411398	2020-10-29 13:33:23.411398	\N
f5c2aa1f-522e-4050-9b58-cb9c85b0508d	9014ee8e-7dd9-4298-9dea-744768dd718f	68bec3c2-26a1-4fb6-8782-5239f6345492	\N	2020-10-29 13:33:23.429019	2020-10-29 13:33:23.429415	2020-10-29 13:33:23.429415	\N
e4efb9b5-fc93-4fea-aa09-76d5bdb9cc7a	2cdcebb4-177f-4292-9025-f777c6ead56b	56e0920e-8d04-47f1-93af-92b104f2bced	\N	2020-10-29 13:33:23.445702	2020-10-29 13:33:23.446	2020-10-29 13:33:23.446	\N
b20a2c6d-00ba-4372-8fd5-442fb8f096f5	4412a70a-a21c-4c20-b64e-9834ffbf80f3	4aafb623-dc12-413f-ab99-cc8df9c6af11	\N	2020-10-29 13:33:23.462196	2020-10-29 13:33:23.46255	2020-10-29 13:33:23.46255	\N
d5efd044-3e0e-47a7-912d-b6d8791c8736	d7a8239f-f83d-4628-97ee-d727daf7d07b	e2281642-3bf1-4875-818c-f8686f3a385e	\N	2020-10-29 13:33:23.479433	2020-10-29 13:33:23.479773	2020-10-29 13:33:23.479773	\N
fcc562f3-ce5e-4f84-acc3-7b6159378961	b8cbed4c-5b09-4577-95a4-27705f9b24a3	de0b7f90-f189-431a-846c-941226971319	\N	2020-10-29 13:33:23.496933	2020-10-29 13:33:23.497254	2020-10-29 13:33:23.497254	\N
1f816603-ed89-4eb1-9f2f-4001de32fcbe	9953cd1c-5fca-4dd3-bdb3-8a8d95419041	07629667-4a5e-4dc1-a5e5-58a543912da8	\N	2020-10-29 13:33:23.514044	2020-10-29 13:33:23.514434	2020-10-29 13:33:23.514434	\N
858153be-7612-478e-9213-950d986dfd7e	62b90969-141e-48df-9598-b1d105786542	365b4c2a-dc17-45e8-a473-e197c4bdf8a0	\N	2020-10-29 13:33:23.531043	2020-10-29 13:33:23.531467	2020-10-29 13:33:23.531467	\N
4d1de76c-912a-439f-8998-c3cde1c070f3	1d8fde4f-3543-4138-88cd-07cdc2fa9a7a	34ea96ba-e2d4-4e6a-ab4d-17f1d7845dff	\N	2020-10-29 13:33:23.548407	2020-10-29 13:33:23.548815	2020-10-29 13:33:23.548815	\N
79595992-1f7d-4e23-9560-f331955681bd	d1571300-0ba3-4620-b120-0d690ece7432	c32cfcb9-8d78-4602-b968-3f9befc6bba3	\N	2020-10-29 13:33:23.565	2020-10-29 13:33:23.56541	2020-10-29 13:33:23.56541	\N
448e9022-9987-47dc-945b-cd698f3b1a6c	ca493cd1-4a4d-43f8-8537-28908f7193f9	5460f08b-ef15-4745-850d-bc645dcd7e0a	\N	2020-10-29 13:33:23.581518	2020-10-29 13:33:23.581949	2020-10-29 13:33:23.581949	\N
fb1d34ac-f800-46f4-85fb-60a715332a04	911b4df8-a802-45c4-a38f-eebaa3f511d3	f853e86a-5821-43c2-ae6b-f4c65b150cfc	\N	2020-10-29 13:33:23.598815	2020-10-29 13:33:23.599206	2020-10-29 13:33:23.599206	\N
cb2136e2-6f73-4f58-873b-46648b0d5dda	d4a176f1-8929-4cca-a8e4-1f28e3d46ac1	3cd0c226-c06a-4b6a-999b-7aa22328bb97	\N	2020-10-29 13:33:23.61931	2020-10-29 13:33:23.619714	2020-10-29 13:33:23.619714	\N
977d1375-9e5f-4649-a17f-8dabf83824bd	e37af862-0995-49bf-a229-2fa38091b5f8	602523c3-1b38-405f-af9d-5fa88a149a67	\N	2020-10-29 13:33:23.638909	2020-10-29 13:33:23.639277	2020-10-29 13:33:23.639277	\N
6658de38-6ade-44e9-992c-50dd45d24543	60c0dc66-33d7-4330-950c-d90162ec2d31	d96ea961-6bac-4a8d-9572-5fa5c2790a7a	\N	2020-10-29 13:33:23.708766	2020-10-29 13:33:23.7093	2020-10-29 13:33:23.7093	\N
a93e986b-3de0-4105-8bd1-710e552dd1e2	23dd8bb7-0ba3-48f4-8586-325b77b85d71	f2c72f4d-2de5-4387-8cbf-6e78558fb7e5	\N	2020-10-29 13:33:23.730499	2020-10-29 13:33:23.733339	2020-10-29 13:33:23.733339	\N
e4b1c5dc-9640-4926-8502-8cb58d5d0c78	7b336aad-daaf-429f-b1a9-3fe8ade5759d	c9058fb1-41a2-496c-888d-2e86226b3398	\N	2020-10-29 13:33:23.760058	2020-10-29 13:33:23.760518	2020-10-29 13:33:23.760518	\N
ee9f656a-7f86-4316-9f29-fbdeb655fd91	05190f5a-f776-4b20-8b85-5430c650e2f0	e65ce639-3dd6-448a-8c0d-f9d1ec2ec76b	\N	2020-10-29 13:33:23.788563	2020-10-29 13:33:23.789131	2020-10-29 13:33:23.789131	\N
696dece3-e1a2-4da5-9a37-80a926df52f5	b337bd99-d9c7-4fe6-bb02-3dded529d126	39805c94-c85d-425b-b480-2701e1559c86	\N	2020-10-29 13:33:23.810217	2020-10-29 13:33:23.810639	2020-10-29 13:33:23.810639	\N
378f7e7d-fd3e-4335-8c73-32a43c95b8ba	02c85def-1fc4-416e-9530-9e4c567edf2e	2d8eae91-effa-4774-8c9c-b1aa9dc882df	\N	2020-10-29 13:33:23.848582	2020-10-29 13:33:23.849005	2020-10-29 13:33:23.849005	\N
497de98e-4647-47e2-9fea-f06cf1bc8a93	89f99131-a057-4148-8041-cdd851b00977	f609f9eb-75d3-45af-9ba8-b56dabd1a10b	\N	2020-10-29 13:33:23.900262	2020-10-29 13:33:23.900748	2020-10-29 13:33:23.900748	\N
689f9564-c0ee-4b31-bda6-da772e96c676	e561070d-3096-4132-87b5-d44b41720511	7b6e38c6-941c-4933-afe7-89ad570e01b4	\N	2020-10-29 13:33:23.920172	2020-10-29 13:33:23.920589	2020-10-29 13:33:23.920589	\N
16cc7ee0-5215-4a2b-8156-61792c7d8f77	c07ec2c5-e77a-43b8-b2ee-00521079fb30	c8dd8b95-c869-4d65-88a3-e7ec3a9f2082	\N	2020-10-29 13:33:23.958555	2020-10-29 13:33:23.958985	2020-10-29 13:33:23.958985	\N
4c7f1acf-b38c-4d01-b7c4-d9390ab9862e	c5977dba-5f26-436c-877f-98f2bd0e31e4	f53247bc-7cf1-41a2-b807-7255da660817	\N	2020-10-29 13:33:23.976642	2020-10-29 13:33:23.977123	2020-10-29 13:33:23.977123	\N
d7487b89-8acd-4d6c-b959-3eff4753caf0	7fabf8f6-0e2b-49e4-8088-50d33ebea38e	e0d5e0c9-d0c7-43d2-8b70-0405dad45560	\N	2020-10-29 13:33:23.996042	2020-10-29 13:33:23.996486	2020-10-29 13:33:23.996486	\N
df937f62-e029-460d-8cde-78f1b6194cb1	f0d787ba-6402-4303-8e9c-ea9ca8181532	53b49b78-0ce9-4cb2-b558-fd5a500a3453	\N	2020-10-29 13:33:24.016483	2020-10-29 13:33:24.017027	2020-10-29 13:33:24.017027	\N
a66072f5-1f20-41b8-ba26-54e63a461817	e05c504c-f5c9-4a5e-a30b-a3cb0559636e	7f7d800f-3e53-424e-b85d-623fba723a30	\N	2020-10-29 13:33:24.037915	2020-10-29 13:33:24.038429	2020-10-29 13:33:24.038429	\N
a82dd8da-228e-40ed-b727-d8d67751d5c2	dfd48447-1cb2-4071-83de-6bc5310ae813	9b85459c-8d9a-46de-8812-658173d4b5d3	\N	2020-10-29 13:33:24.060427	2020-10-29 13:33:24.060787	2020-10-29 13:33:24.060787	\N
8648851e-346e-4343-a982-92c00f1c348b	5c216505-b22a-4049-b4be-36a256156468	20671dff-93fe-43d0-a53e-2e97426c418f	\N	2020-10-29 13:33:24.080574	2020-10-29 13:33:24.081052	2020-10-29 13:33:24.081052	\N
7d97da10-bd7f-473b-9917-337a7db35516	a6e7219c-b8d5-4005-ac00-019aeb69e1c4	c1bad241-8116-4243-aa5d-ed1e2b6488ac	\N	2020-10-29 13:33:24.100003	2020-10-29 13:33:24.100413	2020-10-29 13:33:24.100413	\N
\.


--
-- TOC entry 4354 (class 0 OID 22114)
-- Dependencies: 250
-- Data for Name: classification_polygons; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classification_polygons (id, admin_level, classification_alias_id, geom, geog, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4324 (class 0 OID 21046)
-- Dependencies: 213
-- Data for Name: classification_tree_labels; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classification_tree_labels (id, name, external_source_id, seen_at, created_at, updated_at, internal, deleted_at, visibility) FROM stdin;
b454c30c-93fb-4f71-a2fb-695bd6d21f5a	Geschlecht	\N	2020-10-29 13:33:13.552578	2020-10-29 13:33:13.553424	2020-10-29 13:33:13.553424	f	\N	{show,edit,api,xml,filter,tile,list}
f67a4e7c-9284-4239-a735-50fe8c66bcca	Wochentage	\N	2020-10-29 13:33:13.724401	2020-10-29 13:33:13.724824	2020-10-29 13:33:13.724824	f	\N	{show,edit,api,xml,filter,tile,list}
9633a7ea-d538-44d7-9690-2125d312f926	Monate	\N	2020-10-29 13:33:13.862555	2020-10-29 13:33:13.86298	2020-10-29 13:33:13.86298	f	\N	{show,edit,api,xml,filter,tile,list}
9527178a-3753-4e9c-a73c-cef80a15e4cd	Tags	\N	2020-10-29 13:33:14.0761	2020-10-29 13:33:14.076548	2020-10-29 13:33:14.076548	f	\N	{show,edit,api,xml,filter,tile,list}
c0c28446-71c3-478f-bd62-cc149416b954	Ausgabekanäle	\N	2020-10-29 13:33:14.119997	2020-10-29 13:33:14.120434	2020-10-29 13:33:14.120434	f	\N	{show,edit,api,xml,filter,tile,list}
2c66c478-d1ca-44ed-a826-55f0249f2469	Beschreibungsarten	\N	2020-10-29 13:33:14.170995	2020-10-29 13:33:14.171433	2020-10-29 13:33:14.171433	f	\N	{show,edit,api,xml,filter,tile,list}
9f9c259f-0432-4ca8-b2f6-82ce0cc1c7c0	Informationstypen	\N	2020-10-29 13:33:14.174457	2020-10-29 13:33:14.174844	2020-10-29 13:33:14.174844	f	\N	{show,edit,api,xml,filter,tile,list}
6c697639-e819-4814-b9ff-d5fd503d4c7d	Externe Informationstypen	\N	2020-10-29 13:33:14.177777	2020-10-29 13:33:14.178168	2020-10-29 13:33:14.178168	f	\N	{show,edit,api,xml,filter,tile,list}
fbc13f71-1038-43c9-95af-cf24406b6374	POI - Kategorien	\N	2020-10-29 13:33:14.692038	2020-10-29 13:33:14.692649	2020-10-29 13:33:14.692649	f	\N	{show,edit,api,xml,filter,tile,list}
dd6adaa7-da59-4df6-9e60-eac263e83132	Rechte	\N	2020-10-29 13:33:14.696085	2020-10-29 13:33:14.696526	2020-10-29 13:33:14.696526	f	\N	{show,edit,api,xml,filter,tile,list}
9932a0c1-fac4-422f-910b-400be575a52b	MediaArchive - Tags	\N	2020-10-29 13:33:14.699636	2020-10-29 13:33:14.700075	2020-10-29 13:33:14.700075	f	\N	{show,edit,api,xml,filter,tile,list}
595c61c3-9864-4048-b3a0-54d24e9e45bc	Gourmet-Bewertungen	\N	2020-10-29 13:33:14.703154	2020-10-29 13:33:14.703579	2020-10-29 13:33:14.703579	f	\N	{show,edit,api,xml,filter,tile,list}
8fbd8885-5e68-4468-9825-91bb8fe001ab	Feratel - Veranstaltungstags	\N	2020-10-29 13:33:14.706757	2020-10-29 13:33:14.707218	2020-10-29 13:33:14.707218	f	\N	{show,edit,api,xml,filter,tile,list}
39eb39b0-e495-40c8-830f-e087d50c281d	Externer Status	\N	2020-10-29 13:33:14.825514	2020-10-29 13:33:14.826065	2020-10-29 13:33:14.826065	f	\N	{show,edit,api,xml,filter,tile,list}
7e90485f-26c1-499b-a1fb-7948441c7783	Feratel - Status	\N	2020-10-29 13:33:14.925309	2020-10-29 13:33:14.926192	2020-10-29 13:33:14.926192	f	\N	{show,edit,api,xml,filter,tile,list}
f7f0052e-67eb-4262-a773-a34efc30ebf8	Feratel - Angebot - Status	\N	2020-10-29 13:33:15.003515	2020-10-29 13:33:15.004052	2020-10-29 13:33:15.004052	f	\N	{show,edit,api,xml,filter,tile,list}
c03cc9ab-0952-4a1f-bbbf-3649ddf23ddf	Feratel - Preis - Typ	\N	2020-10-29 13:33:15.040475	2020-10-29 13:33:15.040963	2020-10-29 13:33:15.040963	f	\N	{show,edit,api,xml,filter,tile,list}
7947b4ad-090e-4fc4-b995-e05eb6277588	Länder	\N	2020-10-29 13:33:15.078534	2020-10-29 13:33:15.078982	2020-10-29 13:33:15.078982	f	\N	{show,edit,api,xml,filter,tile,list}
b20adb28-ee69-43c8-9a23-247b700eff56	Ländercodes	\N	2020-10-29 13:33:15.392171	2020-10-29 13:33:15.392657	2020-10-29 13:33:15.392657	f	\N	{show,edit,api,xml}
79e56ae0-1fe6-4831-8999-ef2340b46229	Preis-Währung	\N	2020-10-29 13:33:20.886757	2020-10-29 13:33:20.887299	2020-10-29 13:33:20.887299	f	\N	{show,edit,api,xml,filter,tile,list}
60d76849-cda4-43c7-9664-c383edcd093e	Lizenzen	\N	2020-10-29 13:33:21.075664	2020-10-29 13:33:21.076167	2020-10-29 13:33:21.076167	f	\N	{show,edit,api,xml}
a893e8a3-11f6-4609-8427-e40c2d6c6a9f	Veranstaltungsteilnahmemodus	\N	2020-10-29 13:33:21.428298	2020-10-29 13:33:21.42945	2020-10-29 13:33:21.42945	f	\N	{show,edit,api,xml,filter,tile,list}
bc907ce3-1808-4f8a-8793-2e6c65b0e737	Veranstaltungsstatus	\N	2020-10-29 13:33:21.499293	2020-10-29 13:33:21.499882	2020-10-29 13:33:21.499882	f	\N	{show,edit,api,xml,filter,tile,list}
d776c1f7-fac1-4cac-b359-3a2ae2e2e020	ActionTypes	\N	2020-10-29 13:33:21.605251	2020-10-29 13:33:21.605857	2020-10-29 13:33:21.605857	f	\N	{show,edit,api,xml,filter,tile,list}
1e51be41-560e-4499-8b3f-fe07996eef6c	ItemAvailability	\N	2020-10-29 13:33:21.69634	2020-10-29 13:33:21.696953	2020-10-29 13:33:21.696953	f	\N	{show,edit,api,xml,filter,tile,list}
3d68f72b-6b8d-4181-bdab-ae5cb55b7bd9	Rezeptkategorien	\N	2020-10-29 13:33:21.943991	2020-10-29 13:33:21.944664	2020-10-29 13:33:21.944664	f	\N	{show,edit,api,xml,filter,tile,list}
f14c5761-a7e9-4e1b-9265-f3580bfa182e	Gang (Rezept)	\N	2020-10-29 13:33:22.018161	2020-10-29 13:33:22.018853	2020-10-29 13:33:22.018853	f	\N	{show,edit,api,xml,filter,tile,list}
e371e14c-51f8-414b-86f9-4113e44f75f8	Zielgruppen	\N	2020-10-29 13:33:22.048343	2020-10-29 13:33:22.048874	2020-10-29 13:33:22.048874	f	\N	{show,edit,api,xml,filter,tile,list}
14b8a2b9-40fb-4556-b339-b64482af9fe2	Release-Stati	\N	2020-10-29 13:33:22.052396	2020-10-29 13:33:22.052855	2020-10-29 13:33:22.052855	f	\N	{show,edit,api,xml,filter,tile,list}
78dfa326-2734-4bf8-8e74-35f7576e92af	JetTicket - Eventstatus	\N	2020-10-29 13:33:22.15647	2020-10-29 13:33:22.157045	2020-10-29 13:33:22.157045	f	\N	{show,edit,api,xml,filter,tile,list}
6da5269e-a00f-4f67-b366-0f35ee4be0aa	JetTicket - EventFlags	\N	2020-10-29 13:33:22.282955	2020-10-29 13:33:22.283522	2020-10-29 13:33:22.283522	f	\N	{show,edit,api,xml,filter,tile,list}
34202c81-9fad-4c28-a2f7-0007fe27c018	reisen-fuer-alle.de - Zertifikate	\N	2020-10-29 13:33:22.412018	2020-10-29 13:33:22.412697	2020-10-29 13:33:22.412697	f	\N	{show,edit,api,xml,filter,tile,list}
4cb1dc62-e659-46c0-887f-c458ca71ed8f	Inhaltstypen	\N	2020-10-29 13:33:22.909022	2020-10-29 13:33:22.909786	2020-10-29 13:33:22.909786	f	\N	{filter}
\.


--
-- TOC entry 4323 (class 0 OID 21032)
-- Dependencies: 212
-- Data for Name: classification_trees; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classification_trees (id, external_source_id, parent_classification_alias_id, classification_alias_id, relationship_label, classification_tree_label_id, seen_at, created_at, updated_at, deleted_at) FROM stdin;
18b98c01-f4d0-4d8d-8f4d-a8deadc79f52	\N	\N	bf248cd1-3c69-4afe-bad8-2c52018e351d	\N	b454c30c-93fb-4f71-a2fb-695bd6d21f5a	2020-10-29 13:33:13.637421	2020-10-29 13:33:13.638102	2020-10-29 13:33:13.638102	\N
e2647a33-2edf-4748-88af-66c2b397999b	\N	\N	111c75ee-b649-4512-8004-67b4558525f1	\N	b454c30c-93fb-4f71-a2fb-695bd6d21f5a	2020-10-29 13:33:13.711524	2020-10-29 13:33:13.711925	2020-10-29 13:33:13.711925	\N
b9bf376d-051a-4ac9-8b5e-69fc7a30691b	\N	\N	f57ed69a-a085-4c87-abfa-0c689eb2318c	\N	f67a4e7c-9284-4239-a735-50fe8c66bcca	2020-10-29 13:33:13.733777	2020-10-29 13:33:13.734258	2020-10-29 13:33:13.734258	\N
d8d51637-ea3d-4ed1-809c-5a3a97aeed63	\N	\N	4732d15d-1715-4336-aaa1-0a80806ca143	\N	f67a4e7c-9284-4239-a735-50fe8c66bcca	2020-10-29 13:33:13.755879	2020-10-29 13:33:13.756338	2020-10-29 13:33:13.756338	\N
fb095ac5-bf51-48d7-b2af-bcbd7a66dc24	\N	\N	d0b32309-85e3-4dbb-b41a-e43da9a61f80	\N	f67a4e7c-9284-4239-a735-50fe8c66bcca	2020-10-29 13:33:13.773059	2020-10-29 13:33:13.773485	2020-10-29 13:33:13.773485	\N
49ab385f-6689-4c0f-a90f-1a52921de0e8	\N	\N	762fac59-1292-4671-8b6c-876943fc493e	\N	f67a4e7c-9284-4239-a735-50fe8c66bcca	2020-10-29 13:33:13.797336	2020-10-29 13:33:13.797781	2020-10-29 13:33:13.797781	\N
76be7a55-7a9e-40c0-b015-aecf96cff55f	\N	\N	5e25de13-a296-4a6e-9fa0-ca34e437fe5f	\N	f67a4e7c-9284-4239-a735-50fe8c66bcca	2020-10-29 13:33:13.813689	2020-10-29 13:33:13.814095	2020-10-29 13:33:13.814095	\N
a8ebb819-1cd0-46bc-94a5-a678fec53d25	\N	\N	628348b0-fae8-40b3-8732-a07e7590c047	\N	f67a4e7c-9284-4239-a735-50fe8c66bcca	2020-10-29 13:33:13.83607	2020-10-29 13:33:13.836465	2020-10-29 13:33:13.836465	\N
b47371a0-8a16-495f-b80d-8d6e146a2707	\N	\N	c375d854-ee78-45c0-b203-1e1252ebd94b	\N	f67a4e7c-9284-4239-a735-50fe8c66bcca	2020-10-29 13:33:13.851805	2020-10-29 13:33:13.852193	2020-10-29 13:33:13.852193	\N
2ed0b9e2-c394-4676-93f7-1127fda75a27	\N	\N	b5997502-9de0-413b-9e96-78986b212fff	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:13.871062	2020-10-29 13:33:13.871448	2020-10-29 13:33:13.871448	\N
58898f33-5d18-44fd-ae52-bcedb26c2402	\N	\N	23529ba4-1dc6-4cb1-bece-03e7a51633ef	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:13.901916	2020-10-29 13:33:13.902354	2020-10-29 13:33:13.902354	\N
ba75ec3c-2940-41b8-bff6-f132ba54444b	\N	\N	3ca4f33e-298e-4cbe-93c6-a10ec5d1ff0d	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:13.918065	2020-10-29 13:33:13.918487	2020-10-29 13:33:13.918487	\N
770cb4a5-eb1d-451c-96cc-28bca595855d	\N	\N	be8bcc75-6484-4c49-b081-8fd52100ea9c	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:13.934416	2020-10-29 13:33:13.934776	2020-10-29 13:33:13.934776	\N
d0a38405-aaa4-4027-a28c-d5b0f5686465	\N	\N	d5fc4daf-a6d6-405e-bc27-fe922c30a25c	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:13.950392	2020-10-29 13:33:13.950759	2020-10-29 13:33:13.950759	\N
60de6805-39dd-4dee-9567-e4b192b53f8f	\N	\N	1340b514-af44-4efa-b978-408efbfd3610	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:13.96722	2020-10-29 13:33:13.967654	2020-10-29 13:33:13.967654	\N
4618003f-061a-4831-903b-f0fbf19fdd8b	\N	\N	3551d49b-003e-44ec-badf-081b733364d5	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:13.983627	2020-10-29 13:33:13.984069	2020-10-29 13:33:13.984069	\N
e44241fd-fc01-4e82-a181-c62cbb19a224	\N	\N	8bed8d93-d68d-486d-aaae-8a010e6f2686	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:14.000087	2020-10-29 13:33:14.000514	2020-10-29 13:33:14.000514	\N
38ef771e-f739-4ed1-8609-3f7b18a207ef	\N	\N	b3ae1caf-092d-4a0b-992f-0ed423b8da1b	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:14.016409	2020-10-29 13:33:14.016841	2020-10-29 13:33:14.016841	\N
f5ef8ee3-b494-4771-ac29-a7945bc0bc5b	\N	\N	13101455-5024-4443-a563-a3289706cdae	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:14.032612	2020-10-29 13:33:14.03301	2020-10-29 13:33:14.03301	\N
73cba4b4-fa71-4732-89a6-8f844ffae6c6	\N	\N	d8325e1b-3fdb-4f06-a4b4-67abdd7dbf9f	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:14.048808	2020-10-29 13:33:14.049215	2020-10-29 13:33:14.049215	\N
96860a07-cb12-4fc8-83dd-c51f30de8ee9	\N	\N	13dde352-7056-4d0e-8291-f4585933756f	\N	9633a7ea-d538-44d7-9690-2125d312f926	2020-10-29 13:33:14.065066	2020-10-29 13:33:14.065499	2020-10-29 13:33:14.065499	\N
b0fd3f86-5ed3-4f48-84b0-f295168b28ae	\N	\N	45da7461-120a-49f3-aec7-57312b081759	\N	9527178a-3753-4e9c-a73c-cef80a15e4cd	2020-10-29 13:33:14.085251	2020-10-29 13:33:14.085658	2020-10-29 13:33:14.085658	\N
14ecbad6-73ed-4ca6-bf3b-a855f31f535f	\N	\N	a86c6cda-0577-4029-bcaf-5a6f1feaa0a3	\N	9527178a-3753-4e9c-a73c-cef80a15e4cd	2020-10-29 13:33:14.102241	2020-10-29 13:33:14.10266	2020-10-29 13:33:14.10266	\N
a638afb8-fbe2-4b87-9ac0-4b8c205a3c74	\N	\N	208ca653-ce4e-4be7-9a16-6da9d4ff765f	\N	c0c28446-71c3-478f-bd62-cc149416b954	2020-10-29 13:33:14.128777	2020-10-29 13:33:14.129187	2020-10-29 13:33:14.129187	\N
907e5739-4bf0-49ac-ae53-91e97c0101a8	\N	\N	e06e899d-b9d9-482a-891d-cdf9dfa25890	\N	c0c28446-71c3-478f-bd62-cc149416b954	2020-10-29 13:33:14.144487	2020-10-29 13:33:14.144903	2020-10-29 13:33:14.144903	\N
d4247148-d480-496d-a016-3ed18092b58b	\N	\N	ad305e6d-fac7-40b2-924e-90842323d490	\N	c0c28446-71c3-478f-bd62-cc149416b954	2020-10-29 13:33:14.16037	2020-10-29 13:33:14.160768	2020-10-29 13:33:14.160768	\N
62a128bf-1754-444c-98d0-0131eb1f4694	\N	\N	337edf50-8286-4b20-a476-61afd0c2f289	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.186282	2020-10-29 13:33:14.186642	2020-10-29 13:33:14.186642	\N
2029e17a-163f-422e-b36d-67da21171877	\N	\N	b4da1cd0-9a32-46bd-9a3f-02e0594f1a54	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.201972	2020-10-29 13:33:14.202438	2020-10-29 13:33:14.202438	\N
b34e9f8b-c057-4d55-b986-d2c6e6dffcc9	\N	\N	3521a453-44ca-467c-9a43-ef823b615adf	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.217995	2020-10-29 13:33:14.218357	2020-10-29 13:33:14.218357	\N
32f983dd-9a02-4db5-bc15-20b3167569e6	\N	\N	4d77cc72-7c10-4703-b91d-31bff579d365	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.233718	2020-10-29 13:33:14.234155	2020-10-29 13:33:14.234155	\N
1b74c0f1-01be-4c60-94a2-6375b98b9ab0	\N	\N	5475057f-4592-412f-a79f-05e4857bdc94	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.249249	2020-10-29 13:33:14.249681	2020-10-29 13:33:14.249681	\N
2d6519f6-c81a-4a33-a73a-9e30493c0c5f	\N	\N	3aab0cae-82d4-4491-b6a1-f179350458d5	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.265373	2020-10-29 13:33:14.265774	2020-10-29 13:33:14.265774	\N
bfc96102-cfff-4dc9-8343-1dbaff72a4c5	\N	\N	56c498d9-ccf8-4365-9838-6e2d3d940b17	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.281445	2020-10-29 13:33:14.281876	2020-10-29 13:33:14.281876	\N
bb3dbd17-546d-45fb-8a54-c7835369818d	\N	\N	49e05b74-9608-45e0-8384-1ee28dc49151	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.297795	2020-10-29 13:33:14.298231	2020-10-29 13:33:14.298231	\N
d47ed2d3-a8b8-4a12-bbcd-848d58c9186d	\N	\N	fd540dff-9ff1-41cf-acaa-92cd09e4fb32	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.313649	2020-10-29 13:33:14.314108	2020-10-29 13:33:14.314108	\N
84229e00-f645-4129-b7d3-e9814847d3f6	\N	\N	f81309a1-b16b-4c82-a5f4-4b7775ded168	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.329585	2020-10-29 13:33:14.33	2020-10-29 13:33:14.33	\N
cd1a1bc1-297d-4fe7-96fc-44a67b906574	\N	\N	cb42ecd7-e873-447a-b297-9ef33feb6a61	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.346389	2020-10-29 13:33:14.346791	2020-10-29 13:33:14.346791	\N
82a24db0-3ee1-4111-9c7c-67963c4141d4	\N	\N	8d735758-5980-429e-a90c-6ad822383144	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.362502	2020-10-29 13:33:14.362991	2020-10-29 13:33:14.362991	\N
7fdb9d21-b1e8-4579-816d-ee629030a756	\N	\N	9039c96f-6318-43bd-b69a-a73578124445	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.378801	2020-10-29 13:33:14.379259	2020-10-29 13:33:14.379259	\N
716935c8-61ea-4ee7-aebf-5f0f584c9bc1	\N	\N	74117005-eb2b-462f-9bba-df4b6e29e885	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.401951	2020-10-29 13:33:14.402365	2020-10-29 13:33:14.402365	\N
9e00de1e-1df6-4402-bc2b-caddfd8c27ce	\N	\N	339779f9-5491-4fb9-97ad-48cefe8f542d	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.417992	2020-10-29 13:33:14.418404	2020-10-29 13:33:14.418404	\N
b8917d9a-29fc-4bc6-80de-b70820e9df6a	\N	\N	eda40c83-7adb-43a0-a58b-19dd56e4e5d9	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.434234	2020-10-29 13:33:14.434671	2020-10-29 13:33:14.434671	\N
69851e7e-f3b2-4ea1-a442-fcd11315ff73	\N	\N	5f7a33f1-2425-486b-861f-013d29eef6b3	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.450253	2020-10-29 13:33:14.450672	2020-10-29 13:33:14.450672	\N
6a15cd02-900a-4b76-9859-78b125f1ec92	\N	\N	c5f42523-e73c-4526-aa6e-3f294130a91d	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.466026	2020-10-29 13:33:14.466428	2020-10-29 13:33:14.466428	\N
c78d1522-984b-4518-9743-7101f21455e2	\N	\N	fb08e633-5656-49d8-8bf1-4ff9d8700e37	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.48215	2020-10-29 13:33:14.482564	2020-10-29 13:33:14.482564	\N
506fce99-9ebe-4f33-a47e-0e72f9868d3c	\N	\N	01880fef-c961-4c1f-b0cb-38f18e1f20c1	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.497961	2020-10-29 13:33:14.498363	2020-10-29 13:33:14.498363	\N
123ccdfe-36b9-400b-aeff-2e1fe67c4191	\N	\N	5fb915ca-6557-4c8b-a87b-bd5aeb33ae1a	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.514495	2020-10-29 13:33:14.514972	2020-10-29 13:33:14.514972	\N
598a3f4a-bbaa-4798-9dc1-ca613f135370	\N	\N	59434602-a0c4-43f9-ab32-3b4278c61acd	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.530745	2020-10-29 13:33:14.53116	2020-10-29 13:33:14.53116	\N
fc5804e1-590b-448f-a408-389981c21f40	\N	\N	f3cef5c9-82e6-450d-a628-dc4d84d9e9b4	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.546572	2020-10-29 13:33:14.547031	2020-10-29 13:33:14.547031	\N
5c2ffcc5-3d48-4072-a92f-f56cc2dfe6b6	\N	\N	f017d4b5-5201-4824-832b-0124b2089aec	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.562359	2020-10-29 13:33:14.562758	2020-10-29 13:33:14.562758	\N
83fac47b-19b1-4bac-af56-3d2ef492ec10	\N	\N	0930b05d-907b-466a-88a9-06fb00666d80	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.57804	2020-10-29 13:33:14.57843	2020-10-29 13:33:14.57843	\N
3832a0d9-5c29-4679-bd9b-48695d4911aa	\N	\N	4095f332-2180-4dd9-a187-d19275328392	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.593774	2020-10-29 13:33:14.594179	2020-10-29 13:33:14.594179	\N
3e6e3d20-631b-4849-ba7f-1be9b624b45e	\N	\N	bdf50908-b8e2-4bdc-bca5-ddffab01d3af	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.609357	2020-10-29 13:33:14.609721	2020-10-29 13:33:14.609721	\N
2d26da9f-e6ea-4674-9ff9-8f613fdddb3d	\N	\N	8f62644e-ffdd-48da-a8ea-14393f146440	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.624977	2020-10-29 13:33:14.625428	2020-10-29 13:33:14.625428	\N
c459941c-c7d5-4beb-8c7e-392f5b59fe71	\N	\N	82e65628-d1cc-45fe-a839-5ed265a8825a	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.648345	2020-10-29 13:33:14.648809	2020-10-29 13:33:14.648809	\N
5c033642-d8ee-4bc1-a138-8f61d0b0ad95	\N	\N	161ae833-f72a-44f3-b1e5-70ca30889e4c	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.664788	2020-10-29 13:33:14.665203	2020-10-29 13:33:14.665203	\N
2d1edf60-18cb-47a7-bdc7-56a59a5e9421	\N	\N	841ad96c-2876-42b2-b96a-74d4fc054a84	\N	6c697639-e819-4814-b9ff-d5fd503d4c7d	2020-10-29 13:33:14.680925	2020-10-29 13:33:14.681304	2020-10-29 13:33:14.681304	\N
e5c22daa-7a83-4682-8247-bacf451735e8	\N	\N	57845206-2937-43ae-8e65-c9baecd9a251	\N	8fbd8885-5e68-4468-9825-91bb8fe001ab	2020-10-29 13:33:14.719155	2020-10-29 13:33:14.719625	2020-10-29 13:33:14.719625	\N
49c5c1f9-038a-4c20-97e9-32291719abb5	\N	\N	0e75411d-5018-4390-8a9b-b0635fc7952a	\N	8fbd8885-5e68-4468-9825-91bb8fe001ab	2020-10-29 13:33:14.736079	2020-10-29 13:33:14.736513	2020-10-29 13:33:14.736513	\N
ef470c20-db90-4c79-a7dd-05d7c15ac24a	\N	\N	bbeb21f7-3107-4be8-ad2f-8d149d60cc7f	\N	8fbd8885-5e68-4468-9825-91bb8fe001ab	2020-10-29 13:33:14.75353	2020-10-29 13:33:14.753963	2020-10-29 13:33:14.753963	\N
925c24df-2d6a-4409-993e-305b50085498	\N	\N	2537adce-6e9b-49b1-9b27-9664fc5f8050	\N	8fbd8885-5e68-4468-9825-91bb8fe001ab	2020-10-29 13:33:14.777446	2020-10-29 13:33:14.777931	2020-10-29 13:33:14.777931	\N
b0a1517d-0c9e-44c5-bccd-9f9b11d55042	\N	\N	e9706e76-3e86-4ca3-8ff8-695dc89e601d	\N	8fbd8885-5e68-4468-9825-91bb8fe001ab	2020-10-29 13:33:14.795581	2020-10-29 13:33:14.796071	2020-10-29 13:33:14.796071	\N
d9250dfd-0371-4001-a037-a2df77fe13c3	\N	\N	679f1ab9-6628-46e4-b4f6-5cd969067936	\N	8fbd8885-5e68-4468-9825-91bb8fe001ab	2020-10-29 13:33:14.813465	2020-10-29 13:33:14.813969	2020-10-29 13:33:14.813969	\N
e2570502-4cbf-4913-9485-48ea0ed23c1f	\N	\N	30185785-1ef5-49c2-865f-a17eb7d62269	\N	39eb39b0-e495-40c8-830f-e087d50c281d	2020-10-29 13:33:14.842503	2020-10-29 13:33:14.84349	2020-10-29 13:33:14.84349	\N
250b128d-8076-4e57-a62a-cfe53f77f56c	\N	\N	7ddcab5e-9a31-45c9-bd79-a4aca4fe6372	\N	39eb39b0-e495-40c8-830f-e087d50c281d	2020-10-29 13:33:14.874708	2020-10-29 13:33:14.875976	2020-10-29 13:33:14.875976	\N
dc197088-33f2-4647-9944-13c91c22575b	\N	\N	f36964e7-bf20-4915-86a7-2f02d5958b0c	\N	39eb39b0-e495-40c8-830f-e087d50c281d	2020-10-29 13:33:14.905166	2020-10-29 13:33:14.90586	2020-10-29 13:33:14.90586	\N
4278e74f-d6ba-4f1a-a760-d81e2578db0a	\N	\N	c34e9323-a2b9-406d-b7ff-602d6eab7c4e	\N	7e90485f-26c1-499b-a1fb-7948441c7783	2020-10-29 13:33:14.941754	2020-10-29 13:33:14.942751	2020-10-29 13:33:14.942751	\N
6d079834-4133-4893-ad69-77f7b4326401	\N	\N	bf9ccf9a-cd41-4964-a4e4-f0b87981b605	\N	7e90485f-26c1-499b-a1fb-7948441c7783	2020-10-29 13:33:14.975405	2020-10-29 13:33:14.976567	2020-10-29 13:33:14.976567	\N
e3957c70-bfe3-4e2a-9593-a8a9e90e957f	\N	\N	f8af7274-f0df-493d-b286-c120672a2cf2	\N	f7f0052e-67eb-4262-a773-a34efc30ebf8	2020-10-29 13:33:15.012782	2020-10-29 13:33:15.013198	2020-10-29 13:33:15.013198	\N
bd83b522-5490-43fe-b664-181cc9d6b0d5	\N	\N	ebbe1b3c-1f60-4b55-b00e-b5f82eb52b85	\N	f7f0052e-67eb-4262-a773-a34efc30ebf8	2020-10-29 13:33:15.029026	2020-10-29 13:33:15.029518	2020-10-29 13:33:15.029518	\N
c0a560e0-b82c-4857-aff3-f4de5dd9ff09	\N	\N	6e4afbda-3db4-4767-82f3-d73d75bf897c	\N	c03cc9ab-0952-4a1f-bbbf-3649ddf23ddf	2020-10-29 13:33:15.04987	2020-10-29 13:33:15.050318	2020-10-29 13:33:15.050318	\N
3b618144-0ee4-4f84-852e-591ab316d165	\N	\N	f4244058-b6ac-499e-aa66-c1643475234a	\N	c03cc9ab-0952-4a1f-bbbf-3649ddf23ddf	2020-10-29 13:33:15.067227	2020-10-29 13:33:15.067642	2020-10-29 13:33:15.067642	\N
07f29b1b-e5da-45a1-a181-2a67d80138d2	\N	\N	f4d0ca61-e879-4364-9335-c03b9ca9329a	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.088754	2020-10-29 13:33:15.089259	2020-10-29 13:33:15.089259	\N
ee375bf5-5119-41a4-bd5b-f621fecd5959	\N	\N	b248d1ee-1f1d-4a34-8927-3425482c82f7	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.110773	2020-10-29 13:33:15.111201	2020-10-29 13:33:15.111201	\N
502917e0-a911-4534-b23c-d1b3bf7d79f1	\N	\N	1982cb17-3eb9-4a08-91d8-f4f857533a3f	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.127771	2020-10-29 13:33:15.128311	2020-10-29 13:33:15.128311	\N
eefad229-6498-4762-acba-14806d85e8e4	\N	\N	2a6af101-a35c-481d-9d76-21e363c31596	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.144706	2020-10-29 13:33:15.145121	2020-10-29 13:33:15.145121	\N
9e661713-d5ca-4f9b-933b-a959f23dbcaa	\N	\N	747e0362-b3f5-4d8e-b1c0-888e7e217dc5	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.161705	2020-10-29 13:33:15.162149	2020-10-29 13:33:15.162149	\N
fe35025d-62d6-414a-aa18-b77633bc4833	\N	\N	98f28440-8090-48ac-9e1a-056720370fcb	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.178019	2020-10-29 13:33:15.178555	2020-10-29 13:33:15.178555	\N
a35df765-d0f8-4917-a317-c1edd0a6d3a8	\N	\N	b94e424b-8e82-4ecf-a256-99490b542d56	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.195308	2020-10-29 13:33:15.195817	2020-10-29 13:33:15.195817	\N
89afcb50-1823-4268-aac4-0a5df89319ad	\N	\N	2c921f29-3bca-4577-9eae-c6e0bc4c3a2a	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.21255	2020-10-29 13:33:15.213043	2020-10-29 13:33:15.213043	\N
8ad33af2-aad7-489d-8b0d-c2f98ab727d3	\N	\N	f83ae840-230f-4e7b-8c15-0b8d0453ef70	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.236681	2020-10-29 13:33:15.237136	2020-10-29 13:33:15.237136	\N
b10cb218-416f-4f3b-9ecd-98cc8d71b96e	\N	\N	afe80ac4-d82d-492a-b59c-d0f8a543bcba	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.253851	2020-10-29 13:33:15.254279	2020-10-29 13:33:15.254279	\N
00b7aa21-24d3-4e00-a606-9cd09642c529	\N	\N	85324b6b-0d1c-4642-907e-b3bb0346e39c	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.271037	2020-10-29 13:33:15.271511	2020-10-29 13:33:15.271511	\N
d1302152-fc98-46d6-a856-388c5abea742	\N	\N	cf35cec9-5560-4732-a532-45783007bbc3	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.288052	2020-10-29 13:33:15.288537	2020-10-29 13:33:15.288537	\N
6d7b47b9-d6c1-412a-b172-524a28a383aa	\N	\N	da527921-ee5f-42d3-9d6e-c149d86b3e67	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.30486	2020-10-29 13:33:15.305391	2020-10-29 13:33:15.305391	\N
1314ca09-5be2-42a9-a8de-4263e2256b06	\N	\N	302d20af-9b6d-401a-8715-8a79b9a1c53f	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.321956	2020-10-29 13:33:15.322482	2020-10-29 13:33:15.322482	\N
fa1dff3f-f661-42d3-b8da-ae3dc9c30e47	\N	\N	996295b3-cbdb-4012-ad6d-c30c445f040a	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.34614	2020-10-29 13:33:15.346594	2020-10-29 13:33:15.346594	\N
6923016c-87ad-40fd-b441-ce0ff50fae20	\N	\N	5b709e4a-9729-433e-84e7-d34fd380a70d	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.362644	2020-10-29 13:33:15.363105	2020-10-29 13:33:15.363105	\N
98ac6866-a446-4140-81da-27acc48fbd6b	\N	\N	3f6a502d-68a2-42f9-a193-dffe535114d7	\N	7947b4ad-090e-4fc4-b995-e05eb6277588	2020-10-29 13:33:15.380479	2020-10-29 13:33:15.380943	2020-10-29 13:33:15.380943	\N
56243ca4-f444-4636-a712-83765a7a7049	\N	\N	fd9f5a14-6a1e-410a-b2e6-75ea771b0825	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.401588	2020-10-29 13:33:15.402049	2020-10-29 13:33:15.402049	\N
f7ac0858-7a59-4f45-96b3-9ecfed918cd5	\N	\N	51ee5fa7-690a-44ba-a2d3-3fafa74214c1	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.419255	2020-10-29 13:33:15.419787	2020-10-29 13:33:15.419787	\N
8e5c2af7-6de6-4116-9f1b-ecfdbdfe29ab	\N	\N	91cc62df-9f3e-4154-9e58-9aa4c0e2ff11	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.440834	2020-10-29 13:33:15.441352	2020-10-29 13:33:15.441352	\N
7b30be87-ec11-42c8-a8a2-c5b99b3f797b	\N	\N	30514366-e9a8-4e4d-94b0-35b8901e6159	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.460579	2020-10-29 13:33:15.461062	2020-10-29 13:33:15.461062	\N
b697e7fd-401f-46ca-84e0-e29a5db51cae	\N	\N	951f128d-29ac-4189-81f5-8b6ab66fcf2e	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.477586	2020-10-29 13:33:15.478014	2020-10-29 13:33:15.478014	\N
4652edec-8e5f-4d7f-9eed-797299fdedf0	\N	\N	30a03a04-5685-47a4-a9b0-8e981f5e2e18	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.499183	2020-10-29 13:33:15.499588	2020-10-29 13:33:15.499588	\N
292c447d-2ecb-4e4a-af42-92ceaca8f748	\N	\N	445f838c-0e04-43c4-aa15-5f8e38c0a2b7	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.516713	2020-10-29 13:33:15.517183	2020-10-29 13:33:15.517183	\N
3a04b776-f842-4c28-8d9d-3e5bca07fa14	\N	\N	76617b76-ffc2-43a9-a58b-463684da3f27	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.534011	2020-10-29 13:33:15.534496	2020-10-29 13:33:15.534496	\N
a72a3ab9-4b5d-4208-b6ae-64cdcfcefb53	\N	\N	fdae0a60-ce08-4b75-87df-cde67ea958de	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.55527	2020-10-29 13:33:15.555766	2020-10-29 13:33:15.555766	\N
88ccb128-c42c-41ef-9269-a44536af2906	\N	\N	a4a9cf39-3944-4e9c-a0d0-55aea7939b56	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.572207	2020-10-29 13:33:15.572633	2020-10-29 13:33:15.572633	\N
9ec759fc-9b24-45c6-b74e-8d41b3590082	\N	\N	23ab564e-0a95-4ca3-afd9-4389ce0ff210	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.589297	2020-10-29 13:33:15.589731	2020-10-29 13:33:15.589731	\N
f63cb679-761a-4cdc-b15c-4d6c4b20b9eb	\N	\N	06191f9b-89cf-4a62-8754-5dd52a3665ed	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.607501	2020-10-29 13:33:15.607938	2020-10-29 13:33:15.607938	\N
66a0b7d2-a1dc-4598-8b86-b5147cfd2e4b	\N	\N	4f9d3ef9-3522-424e-b959-99b523b6c420	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.625014	2020-10-29 13:33:15.625521	2020-10-29 13:33:15.625521	\N
1ec68a6a-631a-470c-b32a-ebab45d9818c	\N	\N	fea54fd7-e4a0-4df2-a6c2-6c43ecc4a37b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.643338	2020-10-29 13:33:15.643808	2020-10-29 13:33:15.643808	\N
6ad11f8e-4e36-421d-b0f5-b2f4b21f3d1e	\N	\N	a3374280-2d1d-4361-8046-5adbcc018636	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.666412	2020-10-29 13:33:15.666883	2020-10-29 13:33:15.666883	\N
b9349f8f-8532-447f-bc5c-0f09bfd54e04	\N	\N	a532984d-e360-46a6-a393-7e027342fba0	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.684207	2020-10-29 13:33:15.684715	2020-10-29 13:33:15.684715	\N
69d8de5b-8a95-4307-9696-27c7443eadbf	\N	\N	561a1d5c-7e3d-4219-bb78-8292abeb0b68	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.701629	2020-10-29 13:33:15.702122	2020-10-29 13:33:15.702122	\N
7f551b84-8767-4901-a43d-26ad6a641311	\N	\N	a94f41a7-5402-4647-a1f9-b39bb4abe148	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.719556	2020-10-29 13:33:15.720023	2020-10-29 13:33:15.720023	\N
69b108bf-cd89-47e7-a53a-b35aaa4d4ec5	\N	\N	87667340-ffe7-4aa9-87f9-a8108befadbc	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.737095	2020-10-29 13:33:15.73756	2020-10-29 13:33:15.73756	\N
f48ac12e-ee6f-4f52-a782-de2057838a25	\N	\N	9bc87ce7-8214-46d8-842c-ee471b13bf81	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.754286	2020-10-29 13:33:15.754832	2020-10-29 13:33:15.754832	\N
5a236f0e-8b07-4988-a733-968238dbab93	\N	\N	9a5b561b-eef0-481b-8bd5-8324b404c976	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.776792	2020-10-29 13:33:15.777341	2020-10-29 13:33:15.777341	\N
1541b2b0-56ac-4160-abf2-5173118adaed	\N	\N	342e674b-b990-4822-b95a-2b12c629aadb	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.79507	2020-10-29 13:33:15.795601	2020-10-29 13:33:15.795601	\N
928567d0-97cf-4afc-b242-e343ba60ce92	\N	\N	82900adc-3257-48ab-a6b1-b5493e34ce3a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.814324	2020-10-29 13:33:15.814845	2020-10-29 13:33:15.814845	\N
2c0e850d-2cbe-471b-bfa6-f98a7ac06527	\N	\N	0b29236c-4548-4ef3-8be8-4c00858a9fc3	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.845597	2020-10-29 13:33:15.846727	2020-10-29 13:33:15.846727	\N
09f1e863-1d11-416a-a717-8bce5252d8fe	\N	\N	6d4ae0da-8dcd-4ac7-b12f-a480469cfde6	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.880981	2020-10-29 13:33:15.881834	2020-10-29 13:33:15.881834	\N
1b2b0fa1-7400-4b7d-9b9e-60db07c3b664	\N	\N	4629b195-4661-44aa-8f79-aff0c32836c8	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.909653	2020-10-29 13:33:15.910906	2020-10-29 13:33:15.910906	\N
622040b5-b8bf-4032-88f0-b2089ab5e5ee	\N	\N	5983e035-79f9-4c37-ac7d-cb3073061ddf	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.940686	2020-10-29 13:33:15.942306	2020-10-29 13:33:15.942306	\N
fb42ca53-1dc8-4776-928a-a8be70fb4f34	\N	\N	3fa6a37d-0f4e-4401-93e0-fbad77f3aa37	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:15.976676	2020-10-29 13:33:15.977773	2020-10-29 13:33:15.977773	\N
7c149b5b-f62e-4967-bc77-8f7f432e4ef4	\N	\N	917ceb39-97ef-459e-bd87-a147cfaf7f58	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.008447	2020-10-29 13:33:16.008857	2020-10-29 13:33:16.008857	\N
b6bf034c-53fb-4a61-ba48-90d943baa50e	\N	\N	f91ac06d-1e62-4851-a01b-d19ed0a46376	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.025314	2020-10-29 13:33:16.025722	2020-10-29 13:33:16.025722	\N
aead86cd-59e5-4f2e-8c5a-ff3a1ad89ba0	\N	\N	65f1402d-f87f-41ef-abfc-33728da52900	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.042749	2020-10-29 13:33:16.043213	2020-10-29 13:33:16.043213	\N
f745cb6d-09f8-4dc3-b81b-f6e4b7252dec	\N	\N	22c43fad-a272-42b5-ab30-aa7982be49e8	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.059986	2020-10-29 13:33:16.060451	2020-10-29 13:33:16.060451	\N
32833456-c91e-4a4e-897e-4d5930c8251f	\N	\N	bd8c7c85-eba8-45fe-8efc-9ad6e889042a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.076364	2020-10-29 13:33:16.07679	2020-10-29 13:33:16.07679	\N
b3bbe8c5-63ab-4c14-a8e6-21d5b3822061	\N	\N	13f4a358-0066-4996-adea-d3857c71b629	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.093694	2020-10-29 13:33:16.094144	2020-10-29 13:33:16.094144	\N
5b96b086-c772-436f-a889-61fc0a24ac8a	\N	\N	d276387f-bd6e-4383-ba3d-44e5ef359f73	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.13075	2020-10-29 13:33:16.131557	2020-10-29 13:33:16.131557	\N
4dc2522b-5952-4d89-ab6a-1c0b7133d485	\N	\N	0eef62f7-d5e0-4453-a329-c92882b30f9f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.155323	2020-10-29 13:33:16.155736	2020-10-29 13:33:16.155736	\N
37e90717-5636-43d9-bfd9-835ccf0ba986	\N	\N	7b0f65b3-fdb6-44ac-8224-5510acd53fc2	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.173076	2020-10-29 13:33:16.173486	2020-10-29 13:33:16.173486	\N
6bcc1805-5005-4c6e-a28b-38b89fb27d96	\N	\N	14f7907a-82aa-499e-a6da-dbe1b0cec4ba	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.190354	2020-10-29 13:33:16.190821	2020-10-29 13:33:16.190821	\N
1044ca83-7681-486b-ab0a-7e59c5da9503	\N	\N	590e72e6-c170-43da-a020-84e542567a82	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.207973	2020-10-29 13:33:16.208438	2020-10-29 13:33:16.208438	\N
e7e5b6d3-455e-4d2d-9a48-c27f8f98f1a5	\N	\N	fabfa4e5-f28b-4cf8-9241-1b007008811d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.246342	2020-10-29 13:33:16.247881	2020-10-29 13:33:16.247881	\N
325aa4a1-abc5-459e-b74a-a0e7e082c708	\N	\N	c4c19303-966a-4ad5-a7d6-41935c2cce59	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.299909	2020-10-29 13:33:16.301396	2020-10-29 13:33:16.301396	\N
0a0a746f-0b80-4246-b262-e14ef02431b1	\N	\N	21243d97-684b-4988-9c4e-616b50f2cd54	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.330549	2020-10-29 13:33:16.331271	2020-10-29 13:33:16.331271	\N
2f744ca4-03db-4eec-ad03-93b7d8f90f6f	\N	\N	d93d66b8-5172-4a30-a37e-be63993ee430	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.356769	2020-10-29 13:33:16.357437	2020-10-29 13:33:16.357437	\N
4cfd185e-427f-4d1f-87f2-cf094e5ca44a	\N	\N	3fedc464-d5e9-4601-9b3b-94a234d7d820	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.382546	2020-10-29 13:33:16.383258	2020-10-29 13:33:16.383258	\N
d8eb4137-d341-4860-aec4-1c9833d97c90	\N	\N	4d8ada33-086a-4253-9ce6-3eec768e1f7c	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.408379	2020-10-29 13:33:16.409129	2020-10-29 13:33:16.409129	\N
c1f54114-bfcd-4253-98e9-00fd053ef1d3	\N	\N	df48d185-7bcd-44bb-acf7-ec43457f8e02	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.439572	2020-10-29 13:33:16.440255	2020-10-29 13:33:16.440255	\N
9387a169-5598-4fb2-b33c-5ec2786522a1	\N	\N	853cd528-4a57-4bbc-ab85-adc7a974f18f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.4647	2020-10-29 13:33:16.465406	2020-10-29 13:33:16.465406	\N
0e0d0d45-441d-4e4d-8f56-10627c1fe538	\N	\N	69fbd6cc-d768-42d2-a56f-e51b46506cbc	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.489228	2020-10-29 13:33:16.489861	2020-10-29 13:33:16.489861	\N
0b451edd-3513-402d-97b1-4eb7315ce686	\N	\N	e624cd72-1cdc-4001-884a-ff657e2ec1f4	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.508463	2020-10-29 13:33:16.508838	2020-10-29 13:33:16.508838	\N
1a30ef95-7e46-4e89-a88e-acbd47fb669d	\N	\N	5e384300-4734-434d-98e5-fe9bb2c51d79	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.523762	2020-10-29 13:33:16.524091	2020-10-29 13:33:16.524091	\N
f69d0d5a-ad58-43c1-9b7f-fc19e7cc031e	\N	\N	3e90c9f0-1aa2-4c19-9c12-e2c8d2657b5f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.539079	2020-10-29 13:33:16.5394	2020-10-29 13:33:16.5394	\N
6a728254-0c3b-43ed-965c-29461dd0c3ac	\N	\N	73464c75-923a-45d9-bd39-1332ec2ad624	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.554519	2020-10-29 13:33:16.554946	2020-10-29 13:33:16.554946	\N
a89c7138-4ac9-4a40-b5c7-1845f92727f0	\N	\N	70a92233-3bf5-470b-afc0-ef5919903bad	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.570807	2020-10-29 13:33:16.571241	2020-10-29 13:33:16.571241	\N
ffaf7655-9ef2-4f77-8054-07b09b889839	\N	\N	2765389c-f10f-4a1d-bb56-d902f597aaa1	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.587367	2020-10-29 13:33:16.587756	2020-10-29 13:33:16.587756	\N
53709941-944e-44ce-b95f-7099e7beea8d	\N	\N	9f8fa9e7-4206-4244-ab24-22303eb2f4ad	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.604201	2020-10-29 13:33:16.604593	2020-10-29 13:33:16.604593	\N
27ad90e1-eec3-43a8-895d-8a74a3ac29e5	\N	\N	310f7428-736a-4084-94d8-c5ef2baec831	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.621366	2020-10-29 13:33:16.621821	2020-10-29 13:33:16.621821	\N
1eaf5e0e-58f2-4952-8fc5-9ee53fe6fd6f	\N	\N	979f3dbe-403e-4fde-ad13-ef335a9782f5	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.638503	2020-10-29 13:33:16.638881	2020-10-29 13:33:16.638881	\N
06b6294e-9d73-4325-9f6a-434e717aea82	\N	\N	48f10f78-627c-485c-b04e-31dce3a60d53	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.654486	2020-10-29 13:33:16.654862	2020-10-29 13:33:16.654862	\N
c4aa62d9-5b2d-4abb-8b3e-f8bb13e9fb29	\N	\N	8fb6f6d8-f1dd-4076-9575-8b07e919ffb6	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.669311	2020-10-29 13:33:16.669612	2020-10-29 13:33:16.669612	\N
aff58fbd-b584-4ef0-921f-962eee7788ba	\N	\N	880b1c51-b7b1-4b2b-bee7-e9d43488fe78	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.684524	2020-10-29 13:33:16.684859	2020-10-29 13:33:16.684859	\N
1e1513d1-c1e0-4927-9bb0-5409da8c70a8	\N	\N	b6dc3fc5-dad7-4c90-99e1-3cd566a18c80	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.703173	2020-10-29 13:33:16.703505	2020-10-29 13:33:16.703505	\N
762b8a5e-ac3c-4535-95de-c787cdde7612	\N	\N	7289c9d8-84e9-43d3-80bb-6b72281ab803	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.719016	2020-10-29 13:33:16.71944	2020-10-29 13:33:16.71944	\N
6b3b3ce1-36bd-40a5-99a0-a7befded8db3	\N	\N	1cd4b228-a006-44d4-96bf-8e2686c76216	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.735379	2020-10-29 13:33:16.735809	2020-10-29 13:33:16.735809	\N
2a90a321-4489-4184-b1b6-5c9af40a851d	\N	\N	c917f6f3-e60b-4d9d-8498-ec9b2c29db32	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.751894	2020-10-29 13:33:16.752298	2020-10-29 13:33:16.752298	\N
34bb1471-3d73-43cb-aa04-7956db7eaab5	\N	\N	19c0dba8-9258-49ab-a5f1-791b2d58a84b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.768258	2020-10-29 13:33:16.768688	2020-10-29 13:33:16.768688	\N
d68e8b08-2310-4b27-bf28-e53d2cfa38e5	\N	\N	131fd0d9-e22e-48ea-b27c-c8bae00a615b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.784576	2020-10-29 13:33:16.785007	2020-10-29 13:33:16.785007	\N
26c81a6f-46fe-4b3a-818f-3fbc475047b3	\N	\N	e2c73122-c4f9-480a-8615-f79a45f4a0d2	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.800841	2020-10-29 13:33:16.801292	2020-10-29 13:33:16.801292	\N
db124d61-5990-4234-b43c-46631de451ef	\N	\N	9189df52-6681-4bcb-bf53-9ddb8b04f8ca	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.81798	2020-10-29 13:33:16.818322	2020-10-29 13:33:16.818322	\N
7beb97b2-f596-439f-a59e-da0bb94d480f	\N	\N	5d7cde15-ba21-4e91-96a9-57582a0550bf	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.833386	2020-10-29 13:33:16.833821	2020-10-29 13:33:16.833821	\N
cc5dd55d-12be-44f4-b74a-19d08f87cb22	\N	\N	25590caf-fb21-4b86-9ccc-ed4cafd8ce5d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.869926	2020-10-29 13:33:16.871536	2020-10-29 13:33:16.871536	\N
edeb5aca-d5a7-49e1-8271-f62f5bbb133d	\N	\N	47b98442-53df-4c6f-9fa9-3edac0a11022	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.911999	2020-10-29 13:33:16.912685	2020-10-29 13:33:16.912685	\N
a472f4f2-3de6-4db7-99bd-2b6d0f8e074f	\N	\N	7f44cee9-db74-4787-bb0a-84ef02b846c1	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.934097	2020-10-29 13:33:16.934746	2020-10-29 13:33:16.934746	\N
eabb328c-e506-429b-93b0-3d2e17d3603e	\N	\N	6605d208-512a-46fd-bcec-89ac1959782b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.956594	2020-10-29 13:33:16.957242	2020-10-29 13:33:16.957242	\N
0b677c9a-7ff0-4b92-9f5e-697b9b19da16	\N	\N	3837e79c-6413-46dc-9bc3-4e69e7bf79c4	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:16.996332	2020-10-29 13:33:16.997938	2020-10-29 13:33:16.997938	\N
a9acb37f-5cfb-4b95-8af6-a36f095035ff	\N	\N	c8d687bf-5b76-42e5-b072-894c28ddcaeb	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.033618	2020-10-29 13:33:17.034241	2020-10-29 13:33:17.034241	\N
108dfa92-3fd0-4ef1-b13a-025c7ecaba06	\N	\N	9f8a004a-f800-4f78-8271-5b3815195cbb	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.052731	2020-10-29 13:33:17.053235	2020-10-29 13:33:17.053235	\N
439deaec-434f-4b12-ba79-6eed693cc559	\N	\N	5f6e15a9-4a4e-4edd-9351-188f9fefd630	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.080098	2020-10-29 13:33:17.080743	2020-10-29 13:33:17.080743	\N
cb0f49f7-e3eb-48cb-b51a-e493b5738986	\N	\N	a2142821-bda5-49d3-aeb9-fa17cbb84445	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.100541	2020-10-29 13:33:17.101118	2020-10-29 13:33:17.101118	\N
43143836-771a-4678-8048-f1cdcc632feb	\N	\N	345dfddc-ec13-4d5b-870d-6ade12d2f4d6	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.121033	2020-10-29 13:33:17.121624	2020-10-29 13:33:17.121624	\N
73422d14-58dd-454c-a329-2bfd80625a82	\N	\N	01b4ef8b-1392-4335-8afc-84ae47f2d07a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.141584	2020-10-29 13:33:17.142146	2020-10-29 13:33:17.142146	\N
1d1af024-31e0-48f1-86a1-057774b08903	\N	\N	9d6a8a3e-2c25-42cb-bb47-d4f50e040228	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.162317	2020-10-29 13:33:17.166402	2020-10-29 13:33:17.166402	\N
f1c47a6c-16e8-4765-a6ed-cb8631c2c7aa	\N	\N	5361da06-a09d-49e0-a9da-357ae588c0b0	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.186371	2020-10-29 13:33:17.186906	2020-10-29 13:33:17.186906	\N
fac3fc3e-b1c7-454a-8092-a3a2ce2a5348	\N	\N	b4e3472c-c7d9-443d-904a-a75906ab9b56	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.212171	2020-10-29 13:33:17.213722	2020-10-29 13:33:17.213722	\N
af33b73e-39c4-4194-b173-0eb7e52081d5	\N	\N	6b07934a-d97c-412b-8a29-ec82631df446	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.254581	2020-10-29 13:33:17.25522	2020-10-29 13:33:17.25522	\N
0e736b53-71dd-450d-a5d7-4283fd37bbe8	\N	\N	01840676-cd76-448f-b3e4-c5e9519d2b5d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.273957	2020-10-29 13:33:17.274323	2020-10-29 13:33:17.274323	\N
2bf1875f-88d9-4cd9-879a-4fd781bf2d10	\N	\N	49985697-10e2-4af7-b265-ae2714c461f2	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.290592	2020-10-29 13:33:17.29099	2020-10-29 13:33:17.29099	\N
1364b043-004e-4bf3-bdc5-4759285dc890	\N	\N	1630134f-60b1-447d-ac75-0300ea7a8a77	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.323606	2020-10-29 13:33:17.32524	2020-10-29 13:33:17.32524	\N
6399d926-b644-433f-807f-5873970af863	\N	\N	286e59fb-c7d8-44a5-a93b-ca99a1165135	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.373468	2020-10-29 13:33:17.374234	2020-10-29 13:33:17.374234	\N
70a63212-388f-4548-8fc1-d631cdd9a710	\N	\N	2b11b78f-260b-4056-b2eb-d6b18352e69a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.394021	2020-10-29 13:33:17.39444	2020-10-29 13:33:17.39444	\N
efc14de7-5a19-45fe-bda8-92056946b3e9	\N	\N	3c3bb90f-dffc-4216-822f-e7fd6ccd47f5	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.416813	2020-10-29 13:33:17.41743	2020-10-29 13:33:17.41743	\N
93e9a6a6-7de2-4168-bff5-f82b8750b998	\N	\N	8c83a97a-4cd4-4e51-9d1b-4279adef5ca2	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.444867	2020-10-29 13:33:17.445539	2020-10-29 13:33:17.445539	\N
80369397-f160-46f2-a8c2-b371730d479b	\N	\N	c3fb1069-4dbb-4696-a326-c950e0025ef5	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.465079	2020-10-29 13:33:17.465586	2020-10-29 13:33:17.465586	\N
cc221261-2bca-49a5-ab1b-fb0b62b66aba	\N	\N	4833cf74-cf29-4d53-b8e5-5140472efd48	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.48493	2020-10-29 13:33:17.485456	2020-10-29 13:33:17.485456	\N
faaddc4f-a4aa-49b7-b1a5-8abbb8de791c	\N	\N	73385252-fb0f-466c-b008-321e70cab489	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.504543	2020-10-29 13:33:17.505009	2020-10-29 13:33:17.505009	\N
c142134e-6d8a-4614-9826-332db6aa1d95	\N	\N	4f748f81-0dcb-4c1f-9fcb-9b3aa4beb721	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.524048	2020-10-29 13:33:17.524597	2020-10-29 13:33:17.524597	\N
21d85d72-baea-4904-853a-9aff3a0c0378	\N	\N	11d4842d-b7df-4ad5-9edc-a26adc3f84d1	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.544372	2020-10-29 13:33:17.544918	2020-10-29 13:33:17.544918	\N
a2b28b4a-11e3-457c-a6ce-50e57fdcfa02	\N	\N	046a6186-bc15-469d-b4bf-9fb6fae6de60	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.564276	2020-10-29 13:33:17.564805	2020-10-29 13:33:17.564805	\N
1460cf80-2e25-4af1-81c8-8e7f29a94149	\N	\N	102ff072-00bc-4c23-ada0-ec20e261a966	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.584168	2020-10-29 13:33:17.584722	2020-10-29 13:33:17.584722	\N
4d944049-af76-4d78-b9ab-7bda48354e39	\N	\N	82b864e5-a3bf-43c5-a843-0d9271c176b9	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.603731	2020-10-29 13:33:17.604275	2020-10-29 13:33:17.604275	\N
db721bab-45df-499b-a44d-940038beec15	\N	\N	b6687c63-d127-4a14-ab4b-6eae3c2a64c7	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.637498	2020-10-29 13:33:17.639198	2020-10-29 13:33:17.639198	\N
827b5162-d830-4444-a7f6-db169197e596	\N	\N	6247e58b-3251-4938-a4ea-8991fd31a87e	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.679807	2020-10-29 13:33:17.680452	2020-10-29 13:33:17.680452	\N
25c86f1a-e7d4-4ac1-af3c-110d5b96bd19	\N	\N	64a8381f-e0a5-47eb-bb59-899330f0c57b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.699139	2020-10-29 13:33:17.699558	2020-10-29 13:33:17.699558	\N
2208dc2e-a395-43be-a671-20c118ea74a0	\N	\N	59d21e6c-7d7a-427c-9c6d-48605787a79a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.717357	2020-10-29 13:33:17.717857	2020-10-29 13:33:17.717857	\N
b829263c-5511-45f2-89a2-eb2e87a134e1	\N	\N	29fe6d08-4246-41b3-8184-34be970331f2	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.736526	2020-10-29 13:33:17.736997	2020-10-29 13:33:17.736997	\N
9d80770a-088c-4243-b07f-e478ac4f2b07	\N	\N	46897f07-74ef-4d26-b978-91a379908542	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.755734	2020-10-29 13:33:17.75618	2020-10-29 13:33:17.75618	\N
d33010aa-3823-4e51-8700-0e5962c80888	\N	\N	09216daa-8fdc-41f6-99d4-3b90ad48427f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.773565	2020-10-29 13:33:17.773961	2020-10-29 13:33:17.773961	\N
16390fd4-512a-40bb-b230-a5314d4f597b	\N	\N	23f0e823-3359-4f85-9153-efac7cd00df7	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.792255	2020-10-29 13:33:17.792744	2020-10-29 13:33:17.792744	\N
03f3b912-708d-47cc-9b9b-8ed8064db66c	\N	\N	d1b66578-0e58-47df-9bc3-96b0aedce23f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.810607	2020-10-29 13:33:17.81106	2020-10-29 13:33:17.81106	\N
c091ba1b-5bd3-4224-8d57-c4449be1735d	\N	\N	835249c6-2290-46f0-b61f-ae710a6da88c	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.828781	2020-10-29 13:33:17.829217	2020-10-29 13:33:17.829217	\N
22e79fce-10a5-4fe6-931d-f1e59cf9c27c	\N	\N	253f2092-d981-466f-aae5-7ff01e386e36	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.848268	2020-10-29 13:33:17.848838	2020-10-29 13:33:17.848838	\N
f1409acb-8fcb-4279-8338-f61493ded1b7	\N	\N	aeeced19-e7b4-40ea-8446-7af5d670b735	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.868596	2020-10-29 13:33:17.869169	2020-10-29 13:33:17.869169	\N
798995a9-4a34-42ee-800a-45c484c8d9f1	\N	\N	a18568f2-dfa0-4378-a99e-780db156f192	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.889618	2020-10-29 13:33:17.890211	2020-10-29 13:33:17.890211	\N
f2429b4d-c3ff-49f8-9c3e-87f7c903077e	\N	\N	a31fbd77-f197-4d47-8205-10f1830656fc	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.913439	2020-10-29 13:33:17.914028	2020-10-29 13:33:17.914028	\N
5300372d-b8b0-4527-9fad-b8b9d6b85b48	\N	\N	c14ce860-8653-4e5c-9a8e-4fadaa1c4cff	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.935187	2020-10-29 13:33:17.935773	2020-10-29 13:33:17.935773	\N
fa39a53f-0d5b-4153-9e85-c6dcc796ec88	\N	\N	5acf2e9a-8cbd-4eb8-964b-efdb84ba4567	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.960714	2020-10-29 13:33:17.961349	2020-10-29 13:33:17.961349	\N
b95741f3-b3a5-40f5-9b14-6b4e5849bca3	\N	\N	86f82a47-c5e3-4a9d-9292-99387fbe9adb	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:17.982485	2020-10-29 13:33:17.983044	2020-10-29 13:33:17.983044	\N
8ae69dd3-f87c-46f5-ba71-42f38c898106	\N	\N	5bceef0b-98c1-4787-bbc6-33feb410844b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.008279	2020-10-29 13:33:18.008814	2020-10-29 13:33:18.008814	\N
cdbf6395-6992-4d20-8b8a-9f2b62b96eb6	\N	\N	fd14f83d-86d0-4864-ba9a-a74af0c39413	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.025018	2020-10-29 13:33:18.025458	2020-10-29 13:33:18.025458	\N
3610bd59-466e-44f3-8dda-19892e0582c5	\N	\N	fef44cc5-3c2f-4202-89c9-291522c62728	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.047087	2020-10-29 13:33:18.048651	2020-10-29 13:33:18.048651	\N
475ac936-08d4-472c-91c5-982d565fa29a	\N	\N	bfd59454-c187-4893-9ad2-a11664d95770	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.083874	2020-10-29 13:33:18.084489	2020-10-29 13:33:18.084489	\N
02a26bed-0682-4ff9-ab30-66e6ac3eb576	\N	\N	62b9ea7c-4d9b-4ffb-9384-ee4e6f712cf4	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.102921	2020-10-29 13:33:18.103373	2020-10-29 13:33:18.103373	\N
557eb15b-9db4-4976-b11e-d5679cc462f7	\N	\N	be874081-1efd-4544-aba1-f7fe31775bd3	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.15277	2020-10-29 13:33:18.154698	2020-10-29 13:33:18.154698	\N
4b94da02-b200-46d2-9a38-0c1ed908f1be	\N	\N	d33c4cc3-a89e-459a-a809-6126c0cfb7c2	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.186482	2020-10-29 13:33:18.187082	2020-10-29 13:33:18.187082	\N
e3bdb203-f986-4b3f-a083-792a56501f66	\N	\N	93a436d4-74a4-4bff-90ea-4f3887644cfe	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.207956	2020-10-29 13:33:18.20856	2020-10-29 13:33:18.20856	\N
a6eff7b6-177c-400f-ab88-90c1c21442d6	\N	\N	80f58998-61ab-4c04-9f72-34c05b4de5e0	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.229802	2020-10-29 13:33:18.230318	2020-10-29 13:33:18.230318	\N
e89fcdd1-ca36-4f2f-a6d0-d66c278056f7	\N	\N	b35c32a5-89a1-4446-892b-1ba85490ed92	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.249984	2020-10-29 13:33:18.250462	2020-10-29 13:33:18.250462	\N
6ecf70f0-6770-432c-8e86-c7c635d4a384	\N	\N	b198cfbc-31fe-4bcf-90c1-3db9fa17839b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.269292	2020-10-29 13:33:18.269667	2020-10-29 13:33:18.269667	\N
7d1e78b5-054c-48e0-a493-96e59021dd49	\N	\N	2e7532ed-ccac-4c4e-b425-a36673db68b8	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.286419	2020-10-29 13:33:18.286729	2020-10-29 13:33:18.286729	\N
f8ba8120-7e8d-4fb2-98d3-126a8ba326d0	\N	\N	818d2413-79ab-4d2b-8726-549fc4bc892a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.301293	2020-10-29 13:33:18.301616	2020-10-29 13:33:18.301616	\N
0139ef7c-1f69-42a1-889d-a773bd0dcaf9	\N	\N	e3dc7401-0d98-45d0-829c-093af57ca1d7	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.315162	2020-10-29 13:33:18.315464	2020-10-29 13:33:18.315464	\N
b58c8814-1aef-44f2-833d-f58c16e4226a	\N	\N	f41166f1-802b-4071-b582-95310684117a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.329832	2020-10-29 13:33:18.330124	2020-10-29 13:33:18.330124	\N
32887af3-aa7e-4493-86d5-b2987728cffb	\N	\N	f0ae6ef3-d4fa-4a4b-9116-d02658f6b9df	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.34567	2020-10-29 13:33:18.346109	2020-10-29 13:33:18.346109	\N
3a61f0df-e301-4341-941d-235779a0953d	\N	\N	3193afe6-9274-47b8-b936-413630e5753a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.374261	2020-10-29 13:33:18.375157	2020-10-29 13:33:18.375157	\N
2220b062-3bed-4dff-afe8-9adced396892	\N	\N	e622c6fa-a84d-4208-b278-e6e1e2e154c7	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.396604	2020-10-29 13:33:18.397021	2020-10-29 13:33:18.397021	\N
b032f27f-62e1-4847-921f-96718fb2163f	\N	\N	0707a602-c944-472c-810e-5377f0035909	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.413729	2020-10-29 13:33:18.414178	2020-10-29 13:33:18.414178	\N
db86636c-0dd2-4db8-bff9-10e753e6a310	\N	\N	61f4ccb3-15f1-4969-bc2d-eb774f99a6cd	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.429596	2020-10-29 13:33:18.430005	2020-10-29 13:33:18.430005	\N
8fc9b6b1-ac1d-44da-83d2-4df27f4ac771	\N	\N	d4e70a81-279c-4843-b1a1-ac472aa3e9cc	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.44526	2020-10-29 13:33:18.445694	2020-10-29 13:33:18.445694	\N
41794dd5-d3e1-4ec9-afa3-969f8291d58e	\N	\N	18248783-e520-4291-b0bf-d78a5b4e03cc	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.461585	2020-10-29 13:33:18.461959	2020-10-29 13:33:18.461959	\N
b9e4458b-7628-4cf5-a42e-27494aa00c2d	\N	\N	5f0f395d-81af-41ff-a79c-2daa7d3fdec1	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.479644	2020-10-29 13:33:18.481074	2020-10-29 13:33:18.481074	\N
adcbc31e-876f-451d-8ef1-9ef64fcb57df	\N	\N	813a3766-2cc7-400a-8ca3-504a94ea8d46	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.511075	2020-10-29 13:33:18.511613	2020-10-29 13:33:18.511613	\N
a7cdc833-09d3-405d-bd6d-479494426e1b	\N	\N	9b305531-f99d-49b4-9285-2a07ca7f16de	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.530955	2020-10-29 13:33:18.531353	2020-10-29 13:33:18.531353	\N
3f71237a-7a7d-457b-899b-128fd2aecd23	\N	\N	bda90623-3298-4d31-9d1a-a4232138a5c9	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.548473	2020-10-29 13:33:18.548932	2020-10-29 13:33:18.548932	\N
38cb0439-7e8a-4ab1-ba1e-b03e75b4df09	\N	\N	2ec93c5e-0a9b-4ec9-8151-b9514d2cf522	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.565973	2020-10-29 13:33:18.566451	2020-10-29 13:33:18.566451	\N
ee7cb661-bf21-46ac-9e5e-64416f621911	\N	\N	aadeed45-9435-466c-81c5-c26db07327f2	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.583791	2020-10-29 13:33:18.584264	2020-10-29 13:33:18.584264	\N
1dbd5306-8cb5-4fd3-a1a8-cad7b38bb739	\N	\N	29d094a1-639b-4183-85a5-edf40ec6670b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.601192	2020-10-29 13:33:18.60168	2020-10-29 13:33:18.60168	\N
9cf720bb-43e6-4054-88a7-982dd27d9644	\N	\N	0a1cc10a-42c5-472a-996e-617c7c24b51a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.625801	2020-10-29 13:33:18.626185	2020-10-29 13:33:18.626185	\N
2cc80292-8787-4547-beda-6a35e48f989e	\N	\N	1403b80e-53e8-41c9-8d0d-45cfdeacfbff	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.65005	2020-10-29 13:33:18.651626	2020-10-29 13:33:18.651626	\N
38dad6de-b9b4-4d28-bf80-1aa0fae324ec	\N	\N	3a68f1d3-8507-4b3c-a0bd-74d4d64b830f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.704326	2020-10-29 13:33:18.705767	2020-10-29 13:33:18.705767	\N
edb37cd9-12e6-4e43-b090-4cdbfff45cb9	\N	\N	4f8713d2-1080-4a6a-8f7d-dcec346d7ff4	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.731986	2020-10-29 13:33:18.732602	2020-10-29 13:33:18.732602	\N
d7e6efc7-1773-42d7-b204-8f44427751b3	\N	\N	cc55150d-3ead-48dd-a484-ee194acb5984	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.754726	2020-10-29 13:33:18.755352	2020-10-29 13:33:18.755352	\N
4fedfdaf-97c8-4f4c-92c0-009240e42fac	\N	\N	45a51ead-4ecd-4422-9462-fac73395ac67	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.777697	2020-10-29 13:33:18.778333	2020-10-29 13:33:18.778333	\N
b8706ab5-6db5-4af0-8fa2-7b474b9ad48a	\N	\N	29cc7444-8547-47a8-b3cc-dc2331543e9c	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.809877	2020-10-29 13:33:18.810477	2020-10-29 13:33:18.810477	\N
bca02edb-505b-4509-9c20-2ce9a25fcf6b	\N	\N	c60cacdf-ee5d-4671-b17b-6a283e9cde23	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.834429	2020-10-29 13:33:18.835139	2020-10-29 13:33:18.835139	\N
0fa9dd11-49f8-4cdb-8965-606aa80cd1ee	\N	\N	ee7e929b-05e7-44e6-ac90-906a2eb1cc30	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.857062	2020-10-29 13:33:18.857469	2020-10-29 13:33:18.857469	\N
9e6152f9-ef9c-4679-b248-273ce70104ba	\N	\N	7ef35c04-22d6-49f8-ae00-1ad9ce9711c1	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.873818	2020-10-29 13:33:18.874138	2020-10-29 13:33:18.874138	\N
3f1505b5-a517-49a3-8a00-ce34731b1ca1	\N	\N	87d5ff49-844c-4243-b4ff-84f64dc963a1	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.889016	2020-10-29 13:33:18.889317	2020-10-29 13:33:18.889317	\N
f0618b3e-8ebc-4f89-b522-23baa9461e21	\N	\N	7088fb70-62d1-4017-b3fc-3d776f9cb4b6	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.903535	2020-10-29 13:33:18.903832	2020-10-29 13:33:18.903832	\N
0e0cc9c2-3de4-41fd-8e4d-1d65f88db337	\N	\N	34f67b13-7d29-47ae-93a9-911818b2d42f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.918053	2020-10-29 13:33:18.918367	2020-10-29 13:33:18.918367	\N
ea8d084f-9f5b-4838-b856-7cf91bb79bad	\N	\N	8f918ffa-d8cb-4772-aee6-0fbad308a9a8	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.932724	2020-10-29 13:33:18.933019	2020-10-29 13:33:18.933019	\N
7368baeb-e49d-4c40-9cec-6598f384817e	\N	\N	1aec1e8a-1fd8-4df2-a22d-7c52e3923c49	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.947506	2020-10-29 13:33:18.947812	2020-10-29 13:33:18.947812	\N
bcaf652a-4b2b-43c6-b391-f84f5a323631	\N	\N	afc00d30-c4e4-4767-b20a-380f339e2c91	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.962656	2020-10-29 13:33:18.962964	2020-10-29 13:33:18.962964	\N
2c7d1e97-cdc5-4260-8753-612694acf595	\N	\N	7af786a2-a968-4476-afb2-198f9148f41d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.977494	2020-10-29 13:33:18.977788	2020-10-29 13:33:18.977788	\N
3cf96075-f145-451a-a8bc-688f423126de	\N	\N	56f6ba28-14c3-435a-ad2f-3b5e7e9852b9	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:18.991587	2020-10-29 13:33:18.991891	2020-10-29 13:33:18.991891	\N
368eab21-fa50-40af-b8c0-df2136e903b9	\N	\N	19fd4e36-6f63-46a5-831f-b31b5ba51b07	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.008802	2020-10-29 13:33:19.009866	2020-10-29 13:33:19.009866	\N
f6245b48-162e-4302-ad0b-f7fe505c40e9	\N	\N	be89bbb0-cccc-480e-87ec-fd708cad7e64	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.033317	2020-10-29 13:33:19.033866	2020-10-29 13:33:19.033866	\N
7f9094f6-8fda-40ea-a500-fff8dde6d239	\N	\N	73e6fd48-def4-4e8c-8e4d-d892091d2789	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.052081	2020-10-29 13:33:19.052543	2020-10-29 13:33:19.052543	\N
832361e7-1f9e-4ec8-9f0a-02000f8027ac	\N	\N	313a6f52-df34-4fae-93b9-41bad061a64b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.07027	2020-10-29 13:33:19.070749	2020-10-29 13:33:19.070749	\N
2b130a02-e408-4cdf-b3c4-791447aee1c0	\N	\N	a42a9cdc-6a4d-4270-b81e-20e4252f917c	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.088353	2020-10-29 13:33:19.08888	2020-10-29 13:33:19.08888	\N
0ce052d2-7dda-4ed8-80fe-6937e1eb407a	\N	\N	427ebf7c-2ec6-4385-ac09-89a4612f5192	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.106657	2020-10-29 13:33:19.107155	2020-10-29 13:33:19.107155	\N
757035a8-c3f5-4842-9136-9850765c7f9b	\N	\N	6db5985f-c130-4ba7-9dd9-587b934acc60	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.125407	2020-10-29 13:33:19.125896	2020-10-29 13:33:19.125896	\N
8e1b36d6-4bc1-43d7-b06a-cabec5d4c68b	\N	\N	3f6b6cdd-4f8f-4e37-9344-14e632e62d4f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.144565	2020-10-29 13:33:19.144911	2020-10-29 13:33:19.144911	\N
eace753e-533b-4480-893e-cfb6cc35525c	\N	\N	7d5bdde6-1e08-4e7b-ae08-e915c380c45d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.160078	2020-10-29 13:33:19.160404	2020-10-29 13:33:19.160404	\N
c6fd0e34-85f9-4c4c-921b-49e72a7a3792	\N	\N	efc6869d-f0b6-4c83-bf53-f6caeb58ddc3	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.175899	2020-10-29 13:33:19.176243	2020-10-29 13:33:19.176243	\N
91500f6b-a291-4001-b72a-53ba0b651da9	\N	\N	e9d23551-dfc1-420a-af71-0dc21ca5aa71	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.191786	2020-10-29 13:33:19.192214	2020-10-29 13:33:19.192214	\N
c797c4a3-3d59-4b6e-9d0b-f8baab92b689	\N	\N	96cf989f-92d7-4f8e-b2ea-5dd929b9c8af	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.208005	2020-10-29 13:33:19.20839	2020-10-29 13:33:19.20839	\N
ef0b59a4-a157-49d4-bf14-25d2192f8d69	\N	\N	d1d4421f-e219-423b-bc52-120bb3047a8d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.224338	2020-10-29 13:33:19.224768	2020-10-29 13:33:19.224768	\N
d99fe5ef-7722-4b0b-8ece-216a60c0eb5c	\N	\N	7efabcd9-7411-4ebc-a698-f14efc23e811	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.239245	2020-10-29 13:33:19.239548	2020-10-29 13:33:19.239548	\N
8f15050a-262c-497b-95ef-4069cbe467f1	\N	\N	225d58ba-0e4f-406d-a2b1-9ad82af5af27	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.256479	2020-10-29 13:33:19.256788	2020-10-29 13:33:19.256788	\N
ea7491a0-be9e-4a79-9c93-a27a6ec98535	\N	\N	2845803b-cab7-45d2-a367-7941401945ab	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.271376	2020-10-29 13:33:19.271688	2020-10-29 13:33:19.271688	\N
66c58a82-8837-4d38-8374-a21080b4d648	\N	\N	ae377184-38f8-4538-b4af-8a0146bb1c7a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.286239	2020-10-29 13:33:19.286544	2020-10-29 13:33:19.286544	\N
9d588238-e6cd-4503-85ba-b5092685051d	\N	\N	3b91ce94-5fd9-4d87-a3fe-66d4fc4f074f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.301424	2020-10-29 13:33:19.301731	2020-10-29 13:33:19.301731	\N
ad480b14-4911-4704-944b-ee4ba9612a77	\N	\N	d8408818-8026-4db5-be2a-1c31a38f7d81	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.317194	2020-10-29 13:33:19.317565	2020-10-29 13:33:19.317565	\N
38ae9022-7935-47f3-9c50-582bacec45d5	\N	\N	f0e6aa74-b56a-496b-b3ca-ca32cfe31e6d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.366765	2020-10-29 13:33:19.367572	2020-10-29 13:33:19.367572	\N
b07e1549-8c4a-470a-9fdb-ee1161664d11	\N	\N	72135b47-561d-4428-abd7-ce81fb18343d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.399407	2020-10-29 13:33:19.400291	2020-10-29 13:33:19.400291	\N
545dd7ee-3d26-43c1-9c15-e0c549d6effe	\N	\N	f21b218e-465d-4d3b-ae47-d795e4dce063	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.433078	2020-10-29 13:33:19.433894	2020-10-29 13:33:19.433894	\N
87792faf-cb03-4992-9676-a27af6f088bb	\N	\N	a32bf634-7a3e-4ed4-a582-a8837bbc1d8e	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.474278	2020-10-29 13:33:19.475166	2020-10-29 13:33:19.475166	\N
78a6ee72-c998-42f1-9c7b-5a5b2899233b	\N	\N	b9dd485e-4026-4b05-ab15-e15637450a99	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.501053	2020-10-29 13:33:19.506293	2020-10-29 13:33:19.506293	\N
01a71fb5-db3f-421e-99d4-5ad5d014d87a	\N	\N	bc62f3f9-7185-482f-a071-fd19a69859fb	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.531371	2020-10-29 13:33:19.532106	2020-10-29 13:33:19.532106	\N
5ca92641-439a-4291-aeb8-9cc6d3f07fa1	\N	\N	625b5c44-4ffc-45d0-aa99-dca6b553f80d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.558929	2020-10-29 13:33:19.559626	2020-10-29 13:33:19.559626	\N
b9eca972-5755-4c70-b9ef-8192cb06dbd9	\N	\N	5d1f456c-146f-4952-80b4-bddfbb41923d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.584645	2020-10-29 13:33:19.585311	2020-10-29 13:33:19.585311	\N
05a00686-247d-4db4-b852-61568c600bb3	\N	\N	377a1a0d-aa50-437b-a852-78f29ff569d8	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.610187	2020-10-29 13:33:19.61089	2020-10-29 13:33:19.61089	\N
3e4d46cb-8d18-4a3a-9946-1dfd8ee3ba4b	\N	\N	554412f1-9f39-4d08-a183-7eb70f7bcb18	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.635783	2020-10-29 13:33:19.636421	2020-10-29 13:33:19.636421	\N
62f6cddb-0b6a-4a43-ba17-7f4268176529	\N	\N	4592bfe0-e72d-46df-8a97-f074eaecc7fe	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.661064	2020-10-29 13:33:19.661778	2020-10-29 13:33:19.661778	\N
1ff28774-2ee7-4401-9656-177fc886b03f	\N	\N	670b7372-f05c-4cb6-a8b0-2e42cfa99208	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.686641	2020-10-29 13:33:19.687289	2020-10-29 13:33:19.687289	\N
d91f0a3a-d26d-4f5a-aa96-626f791f7809	\N	\N	4146a53f-5166-4ad8-9387-bc6833d341ab	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.7116	2020-10-29 13:33:19.712301	2020-10-29 13:33:19.712301	\N
21f608db-2097-47f4-ae93-c29b754e7144	\N	\N	956fa2ed-8c30-4195-ab10-48acaaea9e43	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.736979	2020-10-29 13:33:19.737688	2020-10-29 13:33:19.737688	\N
0e0ef2b3-317b-43e1-8f1b-fc3c215778f4	\N	\N	a036d331-2abe-4ce4-b4f0-811bccc1bea4	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.761838	2020-10-29 13:33:19.762453	2020-10-29 13:33:19.762453	\N
6e87ac76-0aa8-4454-b737-7458e3c91620	\N	\N	48aa57e0-bbcd-494a-a987-e471dbb4e793	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.785697	2020-10-29 13:33:19.786148	2020-10-29 13:33:19.786148	\N
215e05f1-be4f-49b3-86ed-2ab4d8ee4db1	\N	\N	46cd8f27-364c-449d-8327-581d1d789692	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.802879	2020-10-29 13:33:19.803235	2020-10-29 13:33:19.803235	\N
ff645ae3-4627-4cfd-9d19-afca63978b79	\N	\N	7e566493-faae-4321-88ac-3143a14b9261	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.8276	2020-10-29 13:33:19.828074	2020-10-29 13:33:19.828074	\N
56c4fadb-b6c2-4ee3-a39b-da7e42f22d73	\N	\N	5ed528dc-f265-46b0-9807-dc8a5cf40a15	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.85316	2020-10-29 13:33:19.853776	2020-10-29 13:33:19.853776	\N
671ed900-aa54-4d4f-bf70-0a0cdbcde5b1	\N	\N	da9c0415-cabc-406d-b47a-c553c62d3b95	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.87927	2020-10-29 13:33:19.879976	2020-10-29 13:33:19.879976	\N
ab4f2cbf-3dae-4c63-ab00-e2a5a4475494	\N	\N	592967e0-8e49-4609-af55-e9b38cbb7463	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.905103	2020-10-29 13:33:19.905796	2020-10-29 13:33:19.905796	\N
d955e2fe-f111-41f2-9a8b-64a66588ced2	\N	\N	923578c1-d1fa-44ed-949b-69c55eccf3a9	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.931621	2020-10-29 13:33:19.932303	2020-10-29 13:33:19.932303	\N
2ab40c5a-0ea6-4a1b-aca5-6af5953afc55	\N	\N	f921b59c-efa8-4328-8b0e-df7faf34907f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.957549	2020-10-29 13:33:19.958291	2020-10-29 13:33:19.958291	\N
2b32a5eb-96a9-4baa-ab15-a911d8af1a0e	\N	\N	d52a7e95-c989-4da6-9e42-530b2a5f0d5a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:19.983859	2020-10-29 13:33:19.984467	2020-10-29 13:33:19.984467	\N
b392ed52-51f2-4f39-9570-1cbecb6c58cb	\N	\N	58833d5c-2a19-4259-b654-647db61c67a4	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.009955	2020-10-29 13:33:20.011553	2020-10-29 13:33:20.011553	\N
76c1f66c-3620-42af-9dcc-914ffc054bb8	\N	\N	4c50516b-768f-4030-8eb3-61b255f73697	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.066101	2020-10-29 13:33:20.067729	2020-10-29 13:33:20.067729	\N
8af3818a-486b-450d-ae65-52f7a8e1f792	\N	\N	8ad20b62-0fa9-4c3c-a066-2fd9359f1f84	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.106671	2020-10-29 13:33:20.107156	2020-10-29 13:33:20.107156	\N
9d9d03ca-0422-4fea-bf7c-127c39fbc932	\N	\N	092ed4a2-cf2b-426e-9f1a-97c173a4908b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.127551	2020-10-29 13:33:20.128093	2020-10-29 13:33:20.128093	\N
fdda5418-4e6a-40cc-a761-24036aa91daa	\N	\N	411503ca-5091-4a56-b5bb-f5433cba378f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.14861	2020-10-29 13:33:20.149171	2020-10-29 13:33:20.149171	\N
f859d5e4-fa0e-4c85-a152-237073d32601	\N	\N	3aaac8e8-805a-4b2c-9d5d-8b16a6dc90f5	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.168999	2020-10-29 13:33:20.169554	2020-10-29 13:33:20.169554	\N
51ab923c-90aa-4751-baf7-5914e9af2ce7	\N	\N	36657f2c-c1be-444a-98c1-173f476146c4	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.189094	2020-10-29 13:33:20.189579	2020-10-29 13:33:20.189579	\N
7ff807c2-4d72-44d7-9f10-a635793c67d3	\N	\N	fd3108e7-7de8-4015-977b-8621efb130c2	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.209564	2020-10-29 13:33:20.210127	2020-10-29 13:33:20.210127	\N
efb70d15-6173-42b3-a4a8-b67c1ae83208	\N	\N	28050ebb-9652-40c9-ba63-22feb33eb312	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.228376	2020-10-29 13:33:20.228795	2020-10-29 13:33:20.228795	\N
d3c0a5ec-707b-41e7-82f0-6b31dd670826	\N	\N	cce2a66d-c5e6-4d03-9d5c-09d8dd1931fd	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.245905	2020-10-29 13:33:20.246256	2020-10-29 13:33:20.246256	\N
82883608-0a1e-45d7-b10b-f878fc9c19f5	\N	\N	e56e857b-6232-476a-a841-4bcbf64dc0f9	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.261137	2020-10-29 13:33:20.261436	2020-10-29 13:33:20.261436	\N
7152706c-867c-4986-9e21-6370a91597cc	\N	\N	8c33cfbc-9f74-4b2e-a924-38b53ccf8871	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.275779	2020-10-29 13:33:20.276087	2020-10-29 13:33:20.276087	\N
38606711-b215-4fc9-984b-e7d9291cdb8a	\N	\N	1dbc877c-2a7f-4d74-87f2-4847a578749e	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.290654	2020-10-29 13:33:20.290957	2020-10-29 13:33:20.290957	\N
6922255e-6caf-49e5-9dc5-ebd6ec54f337	\N	\N	00f0a783-1ae4-425c-b2a7-ee59a6f3ca9e	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.305812	2020-10-29 13:33:20.306131	2020-10-29 13:33:20.306131	\N
cc1163d4-2acf-4f3e-8c2a-1aa240ef945f	\N	\N	64f3ad7f-cb3f-4c4f-81ff-ce904daa128d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.321433	2020-10-29 13:33:20.321854	2020-10-29 13:33:20.321854	\N
79a9ce9d-7ad0-49e3-ab3c-a0601cedea2a	\N	\N	e2aabc15-e462-47c6-b224-71f518d32d6c	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.337759	2020-10-29 13:33:20.338172	2020-10-29 13:33:20.338172	\N
b8753f46-6d5c-47fc-9fc0-6d94187dff9b	\N	\N	ec6ec0f1-f63e-4d4e-b6cb-7960f2c5655f	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.360411	2020-10-29 13:33:20.36086	2020-10-29 13:33:20.36086	\N
07df3832-1dc4-41e6-ab34-7b9f7408e366	\N	\N	055b9518-5808-48f7-a6fd-3239fde1b2e5	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.376975	2020-10-29 13:33:20.377356	2020-10-29 13:33:20.377356	\N
fde8ad2d-c341-483d-ba1b-aa87f4c34a8b	\N	\N	ee0e7be3-fcb6-4c7d-b64c-84c5d206165d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.39584	2020-10-29 13:33:20.39627	2020-10-29 13:33:20.39627	\N
f0ae4b8d-5293-4d52-bafa-ce84256e406b	\N	\N	519d58b5-042e-4999-9a41-85db6b493494	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.428074	2020-10-29 13:33:20.429618	2020-10-29 13:33:20.429618	\N
0f9f792c-ef67-493a-8283-74b1969dd46a	\N	\N	470bfd59-4b22-49af-90ec-fe7908acf37e	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.464743	2020-10-29 13:33:20.466013	2020-10-29 13:33:20.466013	\N
c5f50c69-b082-49a8-9261-9d40d05974e7	\N	\N	f8f47a74-0b97-4964-81f5-34209144cca1	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.503823	2020-10-29 13:33:20.504894	2020-10-29 13:33:20.504894	\N
5a9d2b51-27a0-40c7-87f9-2a8485341174	\N	\N	e7b9270c-dd2e-4ec5-b39f-1472a1d93f7c	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.5393	2020-10-29 13:33:20.53997	2020-10-29 13:33:20.53997	\N
8cad8f77-3e52-4df7-8c7d-a35e181ee82c	\N	\N	e245267b-541a-4dfe-a35e-dc1a699d6133	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.576066	2020-10-29 13:33:20.576598	2020-10-29 13:33:20.576598	\N
b4db893f-33f9-4395-92fe-124d43aade89	\N	\N	6cab0f30-2a5d-494a-a6f1-43f3e26c727b	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.596916	2020-10-29 13:33:20.597399	2020-10-29 13:33:20.597399	\N
d7c494a0-09d6-43d0-b132-40040050b838	\N	\N	3b4b6771-67fb-4079-805e-7944cd2a799d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.626314	2020-10-29 13:33:20.626642	2020-10-29 13:33:20.626642	\N
6ab50ca7-c085-49ee-ab01-a4fe137dc0c4	\N	\N	0f10635a-ac96-4905-b31d-b40449e70c7a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.656849	2020-10-29 13:33:20.657453	2020-10-29 13:33:20.657453	\N
5b812bd6-dc8a-40be-ab54-db30bf9a93b8	\N	\N	7cfec776-57ee-434a-82c7-9bd1e0fd0842	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.678164	2020-10-29 13:33:20.67917	2020-10-29 13:33:20.67917	\N
37f06553-e835-42f6-945a-77e14896e6e1	\N	\N	a13ce5d4-3119-403b-b8ad-5009ef5cfd9c	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.705496	2020-10-29 13:33:20.70584	2020-10-29 13:33:20.70584	\N
58b1575f-266e-46fb-8aae-645c1650b794	\N	\N	5fa93060-a05f-445e-8863-28cfb5599b68	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.720469	2020-10-29 13:33:20.720765	2020-10-29 13:33:20.720765	\N
44ae6341-e75c-4146-905d-e17682c573cb	\N	\N	3ca481b6-4ab5-4b1c-92ec-24f782e01a3c	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.735127	2020-10-29 13:33:20.735422	2020-10-29 13:33:20.735422	\N
95b83dd6-6808-42e9-878c-fe8edfa1646b	\N	\N	ff86616d-91f1-4715-a25f-f6abb98214df	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.750201	2020-10-29 13:33:20.750621	2020-10-29 13:33:20.750621	\N
864a3338-8a1b-4e7d-8636-8d2e87c8415d	\N	\N	573fa4f5-4100-483c-925d-8bd0c4519e78	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.770456	2020-10-29 13:33:20.772529	2020-10-29 13:33:20.772529	\N
767578b0-6459-4fcd-9720-6bd6e4f624f3	\N	\N	c397a9f2-4983-403c-ad34-c29a93115b5a	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.828876	2020-10-29 13:33:20.830479	2020-10-29 13:33:20.830479	\N
81e741b5-dad8-47a7-ac8c-9e9faa2ab402	\N	\N	4cd46fc1-b4a5-44bc-9a3b-4cf2eeea2a1d	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.855675	2020-10-29 13:33:20.856174	2020-10-29 13:33:20.856174	\N
2d538e62-67e5-40ee-aef2-8c61dfdf63ef	\N	\N	c3bc8dbb-dd26-444a-8ef1-1af46cc74246	\N	b20adb28-ee69-43c8-9a23-247b700eff56	2020-10-29 13:33:20.874355	2020-10-29 13:33:20.874836	2020-10-29 13:33:20.874836	\N
9795a889-c691-4eba-9a1d-82c907f720be	\N	\N	df831f44-fa0c-4066-9ce5-b44852a42122	\N	79e56ae0-1fe6-4831-8999-ef2340b46229	2020-10-29 13:33:20.89688	2020-10-29 13:33:20.897382	2020-10-29 13:33:20.897382	\N
1d4b1326-c084-457a-80dd-99379ef8aa27	\N	\N	a82e3b86-206d-45fa-a964-f3a36edb8d12	\N	79e56ae0-1fe6-4831-8999-ef2340b46229	2020-10-29 13:33:20.915572	2020-10-29 13:33:20.916062	2020-10-29 13:33:20.916062	\N
94e12877-86bb-4715-832e-70ea6f7768e3	\N	\N	0b37b573-dd6a-4da2-9101-528bc4e84b6f	\N	79e56ae0-1fe6-4831-8999-ef2340b46229	2020-10-29 13:33:20.933269	2020-10-29 13:33:20.933744	2020-10-29 13:33:20.933744	\N
9bdc72d5-dd34-4415-96c1-0fb31de2a379	\N	\N	f916e428-df94-484c-a913-cae8a1a0629a	\N	79e56ae0-1fe6-4831-8999-ef2340b46229	2020-10-29 13:33:20.972149	2020-10-29 13:33:20.972795	2020-10-29 13:33:20.972795	\N
3321a4fd-361f-4850-b040-ace04de3b83b	\N	\N	0d149210-4782-4d55-8d98-2050dcdf76f8	\N	79e56ae0-1fe6-4831-8999-ef2340b46229	2020-10-29 13:33:20.991811	2020-10-29 13:33:20.992239	2020-10-29 13:33:20.992239	\N
58699d05-b9aa-4e59-b0be-0cb058d2770b	\N	\N	4aa18e08-2c0d-4ba0-936a-04a6f966c9b1	\N	79e56ae0-1fe6-4831-8999-ef2340b46229	2020-10-29 13:33:21.010842	2020-10-29 13:33:21.011332	2020-10-29 13:33:21.011332	\N
6dd965a2-90be-4ae0-be58-9066da65880b	\N	\N	bbf3d9f7-211a-48df-b808-d26e212e05e0	\N	79e56ae0-1fe6-4831-8999-ef2340b46229	2020-10-29 13:33:21.03833	2020-10-29 13:33:21.038771	2020-10-29 13:33:21.038771	\N
e8206f6f-bd17-443d-9d6d-3af633cf9724	\N	\N	eb8b0e84-2578-41ca-b8f6-102e07403aac	\N	79e56ae0-1fe6-4831-8999-ef2340b46229	2020-10-29 13:33:21.062248	2020-10-29 13:33:21.062677	2020-10-29 13:33:21.062677	\N
b3c70779-4c6a-4db2-b1e8-aceeed898d0c	\N	\N	42218a7a-1de6-4ca8-bdd1-1f7af2dfaeb4	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.086992	2020-10-29 13:33:21.087631	2020-10-29 13:33:21.087631	\N
82c2f17e-0563-4e06-b4ef-b191a3a6cb60	\N	42218a7a-1de6-4ca8-bdd1-1f7af2dfaeb4	dc3649e5-2f11-41c9-91b7-502344cfbc87	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.107767	2020-10-29 13:33:21.108283	2020-10-29 13:33:21.108283	\N
1f3b6633-54ba-48dd-884a-5190975a4969	\N	dc3649e5-2f11-41c9-91b7-502344cfbc87	d9d390ce-16e5-403a-92cc-9a27619a1193	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.126346	2020-10-29 13:33:21.12681	2020-10-29 13:33:21.12681	\N
a656a860-7108-4f4f-8191-f24589449109	\N	dc3649e5-2f11-41c9-91b7-502344cfbc87	3ee7b7a9-0f6f-4d17-a8e9-16abe5298035	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.151557	2020-10-29 13:33:21.152026	2020-10-29 13:33:21.152026	\N
309f6a87-a831-4997-ad69-3c5a3582fe67	\N	dc3649e5-2f11-41c9-91b7-502344cfbc87	1418b03c-dead-48aa-895b-fdd63f125d16	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.168991	2020-10-29 13:33:21.169335	2020-10-29 13:33:21.169335	\N
e0f43552-8f2f-45e6-9a17-f9df3a736ff4	\N	1418b03c-dead-48aa-895b-fdd63f125d16	1560ae8a-2769-472c-9965-abb21d746780	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.184549	2020-10-29 13:33:21.184869	2020-10-29 13:33:21.184869	\N
b768ab83-161e-4a59-8b1e-a39d30f9286a	\N	dc3649e5-2f11-41c9-91b7-502344cfbc87	729cd792-5d08-4b7d-9706-07a546088a80	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.201615	2020-10-29 13:33:21.202018	2020-10-29 13:33:21.202018	\N
10ee7619-9e5c-4f7a-b990-6054709dd054	\N	729cd792-5d08-4b7d-9706-07a546088a80	aba7afb9-5f97-4d7b-8c8f-e9f9996ca170	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.221481	2020-10-29 13:33:21.221909	2020-10-29 13:33:21.221909	\N
3b816def-cb4e-478c-9d0a-b04b91edd727	\N	dc3649e5-2f11-41c9-91b7-502344cfbc87	2ed2785e-4022-405a-bdb3-aaaab91b59d7	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.237664	2020-10-29 13:33:21.238084	2020-10-29 13:33:21.238084	\N
b892b4c2-464b-4e57-9c7c-078ba22e425c	\N	2ed2785e-4022-405a-bdb3-aaaab91b59d7	2f32f6c6-de5b-4651-a78e-04f293601fed	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.253571	2020-10-29 13:33:21.253942	2020-10-29 13:33:21.253942	\N
e028c079-49cb-4037-9293-17abc67d90ca	\N	dc3649e5-2f11-41c9-91b7-502344cfbc87	85525b77-0800-4e59-88e4-1d843e78bc6e	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.269344	2020-10-29 13:33:21.269688	2020-10-29 13:33:21.269688	\N
8d2db4e9-af0a-44ef-be01-9c8272f16bd3	\N	85525b77-0800-4e59-88e4-1d843e78bc6e	6c6d98ab-66c1-45be-9fcb-caef7f7a21cf	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.285624	2020-10-29 13:33:21.286012	2020-10-29 13:33:21.286012	\N
ec187b1e-62da-4662-bf0d-b53496e7e12b	\N	dc3649e5-2f11-41c9-91b7-502344cfbc87	b4021eec-e5a6-4598-8c97-f57e2d7ccbd7	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.302061	2020-10-29 13:33:21.302411	2020-10-29 13:33:21.302411	\N
dcc7ac34-03a7-4ae4-ab94-52b867849edf	\N	b4021eec-e5a6-4598-8c97-f57e2d7ccbd7	b8ea3f73-31b7-45f1-981b-0fa1c354791f	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.317673	2020-10-29 13:33:21.318095	2020-10-29 13:33:21.318095	\N
93d91c5d-f8d1-45a0-9150-345b3a27e11d	\N	dc3649e5-2f11-41c9-91b7-502344cfbc87	3ee1339f-f944-462f-ae7b-f9ee1599dd41	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.355486	2020-10-29 13:33:21.356344	2020-10-29 13:33:21.356344	\N
070f8656-a625-4c13-a315-25aaa0cad73c	\N	3ee1339f-f944-462f-ae7b-f9ee1599dd41	62b58faa-c7bd-4429-bf32-a937a8ac3bc9	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.378975	2020-10-29 13:33:21.379488	2020-10-29 13:33:21.379488	\N
809dca0d-04c9-40ef-976d-dcb4540acfd9	\N	\N	45920f24-f224-4014-9d90-6ebf5dfa9d8f	\N	60d76849-cda4-43c7-9664-c383edcd093e	2020-10-29 13:33:21.397097	2020-10-29 13:33:21.397567	2020-10-29 13:33:21.397567	\N
e3f3ed5d-39b3-48cd-bad2-0321d5477fce	\N	\N	30a28261-88ea-492d-a5b4-d2056070e2f4	\N	a893e8a3-11f6-4609-8427-e40c2d6c6a9f	2020-10-29 13:33:21.443415	2020-10-29 13:33:21.443993	2020-10-29 13:33:21.443993	\N
52b7e609-a481-4676-ba82-41990e0fdae5	\N	\N	eb1f94ad-59d9-46bd-a654-9a7a0b401b50	\N	a893e8a3-11f6-4609-8427-e40c2d6c6a9f	2020-10-29 13:33:21.46453	2020-10-29 13:33:21.465067	2020-10-29 13:33:21.465067	\N
1bd9a8b5-01f9-4d58-a889-baafdc9d86d3	\N	\N	030173ab-82be-44ae-9a43-f398f32cf426	\N	a893e8a3-11f6-4609-8427-e40c2d6c6a9f	2020-10-29 13:33:21.485575	2020-10-29 13:33:21.48608	2020-10-29 13:33:21.48608	\N
42e9f974-8b9b-454d-b0be-64954f3eb6b9	\N	\N	6d6afa9c-6b21-4e3c-937c-742a5c345804	\N	bc907ce3-1808-4f8a-8793-2e6c65b0e737	2020-10-29 13:33:21.51006	2020-10-29 13:33:21.510588	2020-10-29 13:33:21.510588	\N
a9e6937a-6641-41a5-b739-b0c6e1bde560	\N	\N	dbd46855-bf17-44f8-9d28-43c5f6bb4723	\N	bc907ce3-1808-4f8a-8793-2e6c65b0e737	2020-10-29 13:33:21.530204	2020-10-29 13:33:21.530747	2020-10-29 13:33:21.530747	\N
6325011a-8449-491a-9b00-a3b73b4adb75	\N	\N	5e9e054a-6043-4b4b-8323-d2b7d3ad8d31	\N	bc907ce3-1808-4f8a-8793-2e6c65b0e737	2020-10-29 13:33:21.55031	2020-10-29 13:33:21.550808	2020-10-29 13:33:21.550808	\N
4263e2af-04c2-4087-89eb-3cf5cf52dbdb	\N	\N	ba16cd9f-a2b1-443b-818a-e771cea9f2e0	\N	bc907ce3-1808-4f8a-8793-2e6c65b0e737	2020-10-29 13:33:21.570513	2020-10-29 13:33:21.571085	2020-10-29 13:33:21.571085	\N
fddea629-00a7-4000-9884-f11108cf96b6	\N	\N	d76a6b42-c85e-4449-ae5d-c61e7e128856	\N	bc907ce3-1808-4f8a-8793-2e6c65b0e737	2020-10-29 13:33:21.591147	2020-10-29 13:33:21.591659	2020-10-29 13:33:21.591659	\N
928b0d03-fc5e-4966-829e-e147d1bf6bf3	\N	\N	5b5aa08d-27ec-45c1-9c2a-42b7cf40f3a5	\N	d776c1f7-fac1-4cac-b359-3a2ae2e2e020	2020-10-29 13:33:21.616374	2020-10-29 13:33:21.616934	2020-10-29 13:33:21.616934	\N
def5dd0e-4e3a-4e7d-b1e7-1c8b0002744d	\N	\N	4104b3d2-5e48-4678-bc36-5530de6081d8	\N	d776c1f7-fac1-4cac-b359-3a2ae2e2e020	2020-10-29 13:33:21.63675	2020-10-29 13:33:21.637295	2020-10-29 13:33:21.637295	\N
8688265e-002d-434c-ab6d-e2fdfdf4ceff	\N	\N	51268410-3a7e-4f84-a7b1-b78aa4c1c087	\N	d776c1f7-fac1-4cac-b359-3a2ae2e2e020	2020-10-29 13:33:21.680845	2020-10-29 13:33:21.681557	2020-10-29 13:33:21.681557	\N
d7dfbda0-929b-4b70-a616-6191bb4d3100	\N	\N	630f7ea2-d57e-4d5b-87f4-3c816c51f73f	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.70762	2020-10-29 13:33:21.708192	2020-10-29 13:33:21.708192	\N
66216903-c47b-4154-b06f-a05b07ed6f8a	\N	\N	9091211f-1547-42f5-b08c-f6d1688c2304	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.728782	2020-10-29 13:33:21.729359	2020-10-29 13:33:21.729359	\N
f5f6dbeb-7b38-4719-abe7-9d6052a07e0d	\N	\N	d2114805-8b70-4899-86d9-92e27e551393	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.750436	2020-10-29 13:33:21.750999	2020-10-29 13:33:21.750999	\N
60e84068-c95a-448f-9c0f-f452c3fb5b37	\N	\N	32c4ee2f-b8bd-4ff9-8130-e962d5329028	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.786654	2020-10-29 13:33:21.787733	2020-10-29 13:33:21.787733	\N
ebe75a48-b70f-4410-b52e-afb1623961f8	\N	\N	85271509-7274-4825-bbd5-209af3918b39	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.824456	2020-10-29 13:33:21.825535	2020-10-29 13:33:21.825535	\N
7a7af43c-0b88-4bb6-9f20-d322fc6477b2	\N	\N	bc001262-28af-4e41-a4fb-666e7c04e908	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.860863	2020-10-29 13:33:21.861525	2020-10-29 13:33:21.861525	\N
725aa32c-473b-4b16-8278-19fcbc19a706	\N	\N	2387d35a-5a36-4ca0-b19a-518417924374	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.884184	2020-10-29 13:33:21.884841	2020-10-29 13:33:21.884841	\N
f512a2e8-6f4b-4b1b-b1e5-645edac53fa3	\N	\N	d8fe2025-31fa-4d8c-88db-890bc2fa79b9	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.906561	2020-10-29 13:33:21.907143	2020-10-29 13:33:21.907143	\N
adc3b209-fdd3-41b4-94a2-665ba0583f62	\N	\N	a21fecd1-5c4d-41cd-869c-b0412ff7093b	\N	1e51be41-560e-4499-8b3f-fe07996eef6c	2020-10-29 13:33:21.928794	2020-10-29 13:33:21.929405	2020-10-29 13:33:21.929405	\N
11c3b1f9-7aa4-494e-bc03-e35d1d0372a2	\N	\N	eb605ee8-2b82-4ed6-a440-7a48b168463c	\N	3d68f72b-6b8d-4181-bdab-ae5cb55b7bd9	2020-10-29 13:33:21.95616	2020-10-29 13:33:21.95678	2020-10-29 13:33:21.95678	\N
bb3bcb09-ed60-42d6-b27b-9d9ff381a3fd	\N	\N	14ea1d8e-7b16-4a60-956c-5119da491179	\N	3d68f72b-6b8d-4181-bdab-ae5cb55b7bd9	2020-10-29 13:33:21.979338	2020-10-29 13:33:21.979989	2020-10-29 13:33:21.979989	\N
0cdef089-4221-4094-814c-bfb599930be8	\N	\N	94aa1447-d880-45bf-b46c-0b65bcc9bd53	\N	3d68f72b-6b8d-4181-bdab-ae5cb55b7bd9	2020-10-29 13:33:22.002327	2020-10-29 13:33:22.002902	2020-10-29 13:33:22.002902	\N
259d7c62-7360-4d81-9ce0-cba7360f2dea	\N	\N	e7a02bbe-e0b1-4a1e-96ce-fc5ee1422c9f	\N	f14c5761-a7e9-4e1b-9265-f3580bfa182e	2020-10-29 13:33:22.034961	2020-10-29 13:33:22.035542	2020-10-29 13:33:22.035542	\N
fd07b6d3-1382-4e54-b7e8-911f38202e00	\N	\N	c193fabb-749a-4a84-af8d-6a630ab82b89	\N	14b8a2b9-40fb-4556-b339-b64482af9fe2	2020-10-29 13:33:22.062323	2020-10-29 13:33:22.062779	2020-10-29 13:33:22.062779	\N
963f2b74-6709-48f1-84f5-241ff7978717	\N	\N	cc1ae4e7-33a7-4436-8c3f-5af7ea4e5d11	\N	14b8a2b9-40fb-4556-b339-b64482af9fe2	2020-10-29 13:33:22.099161	2020-10-29 13:33:22.09986	2020-10-29 13:33:22.09986	\N
73f862bc-2b75-4817-9071-436aaea30c98	\N	\N	0ee39c0b-91b7-4ac6-8a3a-8b34eacf77bd	\N	14b8a2b9-40fb-4556-b339-b64482af9fe2	2020-10-29 13:33:22.122794	2020-10-29 13:33:22.123289	2020-10-29 13:33:22.123289	\N
680f9246-966a-4e49-a0b0-254127c11120	\N	\N	dda670af-ca8a-4268-b471-ede2241f6650	\N	14b8a2b9-40fb-4556-b339-b64482af9fe2	2020-10-29 13:33:22.142816	2020-10-29 13:33:22.14333	2020-10-29 13:33:22.14333	\N
27406b65-bbc7-4d33-80d7-062a3a0a181a	\N	\N	ec023395-e306-43c5-9667-b93bbe09218a	\N	78dfa326-2734-4bf8-8e74-35f7576e92af	2020-10-29 13:33:22.167286	2020-10-29 13:33:22.167769	2020-10-29 13:33:22.167769	\N
1384b3ed-9e96-4d65-aca2-75ee2146033c	\N	\N	ee33caa5-2854-4d0b-90d0-213dece134d8	\N	78dfa326-2734-4bf8-8e74-35f7576e92af	2020-10-29 13:33:22.187658	2020-10-29 13:33:22.18813	2020-10-29 13:33:22.18813	\N
70bbb423-56df-4b65-a5d3-f1fea667e6ef	\N	\N	f0413d70-2dc3-4470-86ca-c25f331d5c2f	\N	78dfa326-2734-4bf8-8e74-35f7576e92af	2020-10-29 13:33:22.208338	2020-10-29 13:33:22.208872	2020-10-29 13:33:22.208872	\N
f9080305-3f84-4b87-b3cc-8dc82fdb8f05	\N	\N	492c49c6-a13c-4466-a365-1ff74891f6e0	\N	78dfa326-2734-4bf8-8e74-35f7576e92af	2020-10-29 13:33:22.228557	2020-10-29 13:33:22.229111	2020-10-29 13:33:22.229111	\N
23c373b8-e17d-4513-9779-5f732193156b	\N	\N	b35d51cb-d5f8-4457-9e8f-6b2985c4df44	\N	78dfa326-2734-4bf8-8e74-35f7576e92af	2020-10-29 13:33:22.249224	2020-10-29 13:33:22.249732	2020-10-29 13:33:22.249732	\N
5f7bfdee-9969-4dc3-99c8-efcca3bca8d7	\N	\N	77ccaa3d-39f8-4e13-aca0-f328497d39c4	\N	78dfa326-2734-4bf8-8e74-35f7576e92af	2020-10-29 13:33:22.269153	2020-10-29 13:33:22.269636	2020-10-29 13:33:22.269636	\N
9f7b4ac5-222b-4f23-9d98-0069387667f3	\N	\N	4d273888-ab7d-4bc8-8617-0c786d27d32c	\N	6da5269e-a00f-4f67-b366-0f35ee4be0aa	2020-10-29 13:33:22.294089	2020-10-29 13:33:22.294642	2020-10-29 13:33:22.294642	\N
93fa2f4c-708d-4a28-9cf0-35ac4b7f4b38	\N	\N	1d3f79df-78c5-41bc-a923-8f4ac0c34fb6	\N	6da5269e-a00f-4f67-b366-0f35ee4be0aa	2020-10-29 13:33:22.316849	2020-10-29 13:33:22.317387	2020-10-29 13:33:22.317387	\N
a5be546e-beed-4e3f-ac1b-93cf082dcd47	\N	\N	3b9cbd67-3073-461b-984a-1711b5c6bc73	\N	6da5269e-a00f-4f67-b366-0f35ee4be0aa	2020-10-29 13:33:22.336995	2020-10-29 13:33:22.337489	2020-10-29 13:33:22.337489	\N
3e9cfb34-4163-4e2f-8a7c-0642eec469fb	\N	\N	4856be18-7fd2-4df9-b216-c5da68744c74	\N	6da5269e-a00f-4f67-b366-0f35ee4be0aa	2020-10-29 13:33:22.37184	2020-10-29 13:33:22.372672	2020-10-29 13:33:22.372672	\N
c5e80edd-3772-495e-a653-8914eb41b1f7	\N	\N	e8f1f614-f8a4-43e7-a03a-07e278c0495c	\N	6da5269e-a00f-4f67-b366-0f35ee4be0aa	2020-10-29 13:33:22.395942	2020-10-29 13:33:22.396578	2020-10-29 13:33:22.396578	\N
2b1d5e4d-836e-402c-b9db-20edbccae403	\N	\N	40f71bfc-e804-488e-b88b-3a7eaa493f54	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.424513	2020-10-29 13:33:22.42512	2020-10-29 13:33:22.42512	\N
edc40d67-77d5-46c9-84b0-ebc7e74f939f	\N	40f71bfc-e804-488e-b88b-3a7eaa493f54	ca5c07df-275e-43ca-a3fa-0e6fe7b86ff0	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.447509	2020-10-29 13:33:22.448101	2020-10-29 13:33:22.448101	\N
0ea57f13-c9e2-473e-9184-ff0f6d57d013	\N	40f71bfc-e804-488e-b88b-3a7eaa493f54	6be32111-1a17-487c-a043-e855fd8227a4	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.470079	2020-10-29 13:33:22.47071	2020-10-29 13:33:22.47071	\N
91aae590-c90b-49c1-961e-cd8169398651	\N	\N	478150c9-6e0c-4e43-9e29-ebcc3fbb0ed6	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.49336	2020-10-29 13:33:22.493994	2020-10-29 13:33:22.493994	\N
8093a936-8fcc-40a2-803c-34c2326993b7	\N	478150c9-6e0c-4e43-9e29-ebcc3fbb0ed6	4eaf933f-aac2-44d2-b6e3-227abb6be846	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.516721	2020-10-29 13:33:22.517216	2020-10-29 13:33:22.517216	\N
eaf7fabc-3f8e-4042-bf77-c283f9c392aa	\N	478150c9-6e0c-4e43-9e29-ebcc3fbb0ed6	10135158-e789-4ed7-9044-15edb8f27cab	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.536033	2020-10-29 13:33:22.536408	2020-10-29 13:33:22.536408	\N
ed254139-0637-4c31-b278-5dffbf9a78be	\N	\N	8d480b0f-2525-47fa-9f80-f91786908a3e	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.552712	2020-10-29 13:33:22.553135	2020-10-29 13:33:22.553135	\N
c9b2bc2c-d9d7-4356-b124-e5fdbd804cf3	\N	8d480b0f-2525-47fa-9f80-f91786908a3e	5ac4d7f5-52fa-48a3-a693-9f0bc368dad6	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.578507	2020-10-29 13:33:22.578955	2020-10-29 13:33:22.578955	\N
3afbf6b3-d4ed-46d0-ae38-c7cb860fa5b3	\N	8d480b0f-2525-47fa-9f80-f91786908a3e	62f8a278-0779-46d2-8056-f2b11ceba2da	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.597131	2020-10-29 13:33:22.597641	2020-10-29 13:33:22.597641	\N
04f46b72-8ff6-469d-bacc-9baca8305db3	\N	\N	b6437356-9b02-4499-8cea-bcf5b1b2234e	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.615455	2020-10-29 13:33:22.616004	2020-10-29 13:33:22.616004	\N
faa7be84-0f24-4406-8bb7-53a42b5ec11c	\N	b6437356-9b02-4499-8cea-bcf5b1b2234e	5cc51c27-7afe-47d9-8892-d8e2847f32d7	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.634286	2020-10-29 13:33:22.63472	2020-10-29 13:33:22.63472	\N
c6076bb0-ee9d-4a76-880b-ac8d6fc1e4b4	\N	b6437356-9b02-4499-8cea-bcf5b1b2234e	8730793f-18bf-42df-b53b-710f6472b5c7	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.653267	2020-10-29 13:33:22.65377	2020-10-29 13:33:22.65377	\N
88d17811-2ce2-400e-8a0f-d1e9f799be98	\N	\N	211a9552-6b8c-419d-8467-83db49e8ddc8	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.685748	2020-10-29 13:33:22.686771	2020-10-29 13:33:22.686771	\N
b9fc9591-a05f-47e6-9773-4130ea21e7aa	\N	211a9552-6b8c-419d-8467-83db49e8ddc8	0e22570b-b9af-4533-bd96-0e363679c945	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.719597	2020-10-29 13:33:22.720208	2020-10-29 13:33:22.720208	\N
2d14c378-a609-4723-b80f-1105985d1159	\N	211a9552-6b8c-419d-8467-83db49e8ddc8	5d552dfa-f89a-4027-a363-f1b1d515b820	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.740196	2020-10-29 13:33:22.740644	2020-10-29 13:33:22.740644	\N
2b3cc7e6-6afc-4171-bcf1-cbf402d4d3db	\N	\N	e498dca6-bf17-44bc-9139-3ad5cfaca753	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.760974	2020-10-29 13:33:22.76152	2020-10-29 13:33:22.76152	\N
41e4cf80-b8c4-44ea-ae1b-8da08a6d786b	\N	e498dca6-bf17-44bc-9139-3ad5cfaca753	9fd3b7f1-fb1c-4c27-acb0-1c328a6e0065	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.781141	2020-10-29 13:33:22.781689	2020-10-29 13:33:22.781689	\N
0ea16046-d75b-46f8-ac18-82788f2c0e4c	\N	e498dca6-bf17-44bc-9139-3ad5cfaca753	7caf571d-90f5-4dfc-8410-11ecd36a46a0	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.804444	2020-10-29 13:33:22.804945	2020-10-29 13:33:22.804945	\N
fef3e4ae-0600-411c-898d-a7458906e903	\N	\N	0d4f5511-0a1f-40ef-b7e3-dfaf611bfb66	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.825688	2020-10-29 13:33:22.826251	2020-10-29 13:33:22.826251	\N
a9e7e639-c31c-4d09-8969-2de23807bb46	\N	0d4f5511-0a1f-40ef-b7e3-dfaf611bfb66	f9a415db-2068-4e75-8ef7-4d89f86e7a61	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.849374	2020-10-29 13:33:22.849834	2020-10-29 13:33:22.849834	\N
24768396-c81a-49eb-882f-f895630472f1	\N	0d4f5511-0a1f-40ef-b7e3-dfaf611bfb66	0691a5a6-d5d8-4890-afc1-6c930f8de5b7	\N	34202c81-9fad-4c28-a2f7-0007fe27c018	2020-10-29 13:33:22.888042	2020-10-29 13:33:22.889623	2020-10-29 13:33:22.889623	\N
b8d386f9-87cf-4931-886f-cc770181ab56	\N	\N	5cd482ae-f03a-47d0-be49-0546142a54e5	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:22.923084	2020-10-29 13:33:22.923813	2020-10-29 13:33:22.923813	\N
83ec143f-2496-42a0-b9f2-78c9ef83a7aa	\N	5cd482ae-f03a-47d0-be49-0546142a54e5	eb67d4b7-8bb1-4101-806c-18f4f8f97fc4	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:22.9489	2020-10-29 13:33:22.949598	2020-10-29 13:33:22.949598	\N
53b80948-4877-4442-b65b-1b57d036dc76	\N	5cd482ae-f03a-47d0-be49-0546142a54e5	d02ae872-0768-4d0d-814f-90d3d131bef1	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:22.986229	2020-10-29 13:33:22.986761	2020-10-29 13:33:22.986761	\N
15b282e3-39aa-4086-91eb-a02189918d6f	\N	\N	103512a5-8595-4528-b859-210a5021d531	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.0039	2020-10-29 13:33:23.004382	2020-10-29 13:33:23.004382	\N
db33abcd-1959-4c49-aa59-6da7793120d4	\N	103512a5-8595-4528-b859-210a5021d531	00b3b85f-ae65-48c2-a5b9-713929f41251	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.021555	2020-10-29 13:33:23.02203	2020-10-29 13:33:23.02203	\N
bbb5eba1-7853-438a-851c-a71eb3c34625	\N	103512a5-8595-4528-b859-210a5021d531	5e6cf422-1697-4fb7-9612-92e00cbc9c70	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.04114	2020-10-29 13:33:23.041598	2020-10-29 13:33:23.041598	\N
239d8081-1ed8-4b7d-9bce-155116f5cd9a	\N	103512a5-8595-4528-b859-210a5021d531	22890874-16a4-4136-91bd-71e88a822d1c	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.059394	2020-10-29 13:33:23.059783	2020-10-29 13:33:23.059783	\N
02212f47-0029-41ec-8c1e-444d25701601	\N	103512a5-8595-4528-b859-210a5021d531	21ad2ac9-3441-47f5-bc42-90ea910ef3be	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.101547	2020-10-29 13:33:23.103342	2020-10-29 13:33:23.103342	\N
efe47fd3-747f-473d-80fc-509657ec60a3	\N	103512a5-8595-4528-b859-210a5021d531	2bd75a7e-dec8-41a5-af02-cf9f3ea17ed6	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.142683	2020-10-29 13:33:23.143379	2020-10-29 13:33:23.143379	\N
e5b178e6-6e36-449c-a286-75e1e9bde1e1	\N	103512a5-8595-4528-b859-210a5021d531	b25af9fa-ebbc-4b57-980a-afe3458a2d54	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.167429	2020-10-29 13:33:23.168016	2020-10-29 13:33:23.168016	\N
5144ef50-a930-4b3f-b9d7-7a5801c7d21d	\N	103512a5-8595-4528-b859-210a5021d531	3d184ce1-87af-4c86-bec9-d88904d3d622	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.190037	2020-10-29 13:33:23.190655	2020-10-29 13:33:23.190655	\N
a9a29641-1216-4adc-8f3b-163d6679cde7	\N	103512a5-8595-4528-b859-210a5021d531	4daaf11c-36e0-4339-ace8-f57f33cac27b	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.212094	2020-10-29 13:33:23.212674	2020-10-29 13:33:23.212674	\N
e6073fa6-bd3f-4e11-b08f-13885d133560	\N	\N	9b18e490-806c-4ce5-b272-99f53c63f49f	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.234217	2020-10-29 13:33:23.234828	2020-10-29 13:33:23.234828	\N
ad4599ef-42dd-4519-afb4-8b458f87918c	\N	9b18e490-806c-4ce5-b272-99f53c63f49f	4ac59333-587c-4d6b-b371-1e6472a1b6b5	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.25647	2020-10-29 13:33:23.257066	2020-10-29 13:33:23.257066	\N
881b2cc9-4ab2-415a-b5b5-99c3a39cc6fd	\N	9b18e490-806c-4ce5-b272-99f53c63f49f	f5d68b40-ff74-4491-bd11-39f87aa1b6ae	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.28091	2020-10-29 13:33:23.281576	2020-10-29 13:33:23.281576	\N
8bc8be35-0584-4ee4-bce9-7a58a084c68a	\N	9b18e490-806c-4ce5-b272-99f53c63f49f	df0fedb2-e489-438f-8109-53f3e86e517d	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.305516	2020-10-29 13:33:23.306152	2020-10-29 13:33:23.306152	\N
68af455e-700f-4151-8e47-abfba65ae586	\N	\N	b1c80616-e5b2-42b1-b8ff-778904736860	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.330922	2020-10-29 13:33:23.331439	2020-10-29 13:33:23.331439	\N
4b272076-a118-40b5-a764-d4eef152f6df	\N	\N	e4d48892-8970-41ca-adb0-ee988bd61bdd	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.350738	2020-10-29 13:33:23.351117	2020-10-29 13:33:23.351117	\N
1280b2d7-f437-40b0-8e57-44215b934ac3	\N	\N	4f97ee10-706a-4c92-8160-c93cdd5815ce	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.369052	2020-10-29 13:33:23.369452	2020-10-29 13:33:23.369452	\N
6be2d795-d694-45ae-9219-dd5894e3d1a0	\N	\N	c38e4c8b-959d-4f7a-afa0-3c953f9169fa	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.385859	2020-10-29 13:33:23.386207	2020-10-29 13:33:23.386207	\N
ad2a67c7-c144-4e12-8338-7d714a5c3a39	\N	c38e4c8b-959d-4f7a-afa0-3c953f9169fa	d2f18240-24ab-4ddd-8a74-49676ebfb5b3	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.402838	2020-10-29 13:33:23.403245	2020-10-29 13:33:23.403245	\N
8fe33aa3-55b9-4c14-b2a5-eb08125d5bfc	\N	c38e4c8b-959d-4f7a-afa0-3c953f9169fa	68bec3c2-26a1-4fb6-8782-5239f6345492	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.420104	2020-10-29 13:33:23.420482	2020-10-29 13:33:23.420482	\N
11849b71-0bd5-43a0-8219-40b62f00d8a1	\N	c38e4c8b-959d-4f7a-afa0-3c953f9169fa	56e0920e-8d04-47f1-93af-92b104f2bced	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.438034	2020-10-29 13:33:23.438422	2020-10-29 13:33:23.438422	\N
5e2996e3-3b3a-42bb-b795-7cca62e38d97	\N	\N	4aafb623-dc12-413f-ab99-cc8df9c6af11	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.454234	2020-10-29 13:33:23.454645	2020-10-29 13:33:23.454645	\N
9feb234c-3c94-4b34-9b37-2dd481898643	\N	\N	e2281642-3bf1-4875-818c-f8686f3a385e	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.471145	2020-10-29 13:33:23.471527	2020-10-29 13:33:23.471527	\N
5855a126-5dbc-4aa9-b240-f6e4fa863001	\N	\N	de0b7f90-f189-431a-846c-941226971319	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.489034	2020-10-29 13:33:23.489529	2020-10-29 13:33:23.489529	\N
ac32caa4-a4a8-4697-8d96-965456ed63be	\N	\N	07629667-4a5e-4dc1-a5e5-58a543912da8	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.506033	2020-10-29 13:33:23.506448	2020-10-29 13:33:23.506448	\N
5ae8858c-854f-4d72-8d30-39cf72ba47a0	\N	\N	365b4c2a-dc17-45e8-a473-e197c4bdf8a0	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.523239	2020-10-29 13:33:23.523647	2020-10-29 13:33:23.523647	\N
9325e955-6792-49f0-bc71-252b10ec2c52	\N	\N	34ea96ba-e2d4-4e6a-ab4d-17f1d7845dff	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.540737	2020-10-29 13:33:23.541097	2020-10-29 13:33:23.541097	\N
76afad1f-5210-495e-a17c-61e97156c5ad	\N	\N	c32cfcb9-8d78-4602-b968-3f9befc6bba3	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.557567	2020-10-29 13:33:23.55794	2020-10-29 13:33:23.55794	\N
026c28ea-c4e5-404d-a1fc-9495da05a53f	\N	\N	5460f08b-ef15-4745-850d-bc645dcd7e0a	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.573911	2020-10-29 13:33:23.574255	2020-10-29 13:33:23.574255	\N
c0df0476-0abb-4d8a-a31c-e77f39974fa0	\N	\N	f853e86a-5821-43c2-ae6b-f4c65b150cfc	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.590427	2020-10-29 13:33:23.590768	2020-10-29 13:33:23.590768	\N
ffc43957-8aff-49e2-82f8-c0d770baef0e	\N	\N	3cd0c226-c06a-4b6a-999b-7aa22328bb97	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.607605	2020-10-29 13:33:23.607981	2020-10-29 13:33:23.607981	\N
8cf1b633-9102-445d-a16d-ab8208f40923	\N	\N	602523c3-1b38-405f-af9d-5fa88a149a67	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.62962	2020-10-29 13:33:23.630298	2020-10-29 13:33:23.630298	\N
fb522e69-9dcf-4d63-b517-cfe357ed30fc	\N	9b18e490-806c-4ce5-b272-99f53c63f49f	d96ea961-6bac-4a8d-9572-5fa5c2790a7a	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.697737	2020-10-29 13:33:23.698198	2020-10-29 13:33:23.698198	\N
3c9478d6-c28f-406b-8917-c043a6b3ce1b	\N	9b18e490-806c-4ce5-b272-99f53c63f49f	f2c72f4d-2de5-4387-8cbf-6e78558fb7e5	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.719941	2020-10-29 13:33:23.720365	2020-10-29 13:33:23.720365	\N
fe261371-5b46-4d97-bb9b-aacdcb8f98c5	\N	\N	c9058fb1-41a2-496c-888d-2e86226b3398	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.74555	2020-10-29 13:33:23.746167	2020-10-29 13:33:23.746167	\N
00036dd1-fdea-4af8-b342-fad9e846e5d9	\N	\N	e65ce639-3dd6-448a-8c0d-f9d1ec2ec76b	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.774171	2020-10-29 13:33:23.774691	2020-10-29 13:33:23.774691	\N
598da518-ff25-4a6b-bff1-0f75cd8f9dab	\N	\N	39805c94-c85d-425b-b480-2701e1559c86	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.800954	2020-10-29 13:33:23.801448	2020-10-29 13:33:23.801448	\N
7b296bc1-9363-4f35-86e1-db7c6e839f9f	\N	5cd482ae-f03a-47d0-be49-0546142a54e5	2d8eae91-effa-4774-8c9c-b1aa9dc882df	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.840346	2020-10-29 13:33:23.840737	2020-10-29 13:33:23.840737	\N
d7c44646-abef-444b-a468-d83abbf56346	\N	5cd482ae-f03a-47d0-be49-0546142a54e5	f609f9eb-75d3-45af-9ba8-b56dabd1a10b	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.891434	2020-10-29 13:33:23.891814	2020-10-29 13:33:23.891814	\N
ad339594-5e46-48dc-b5ef-992291b8ab5e	\N	5cd482ae-f03a-47d0-be49-0546142a54e5	7b6e38c6-941c-4933-afe7-89ad570e01b4	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.910302	2020-10-29 13:33:23.910709	2020-10-29 13:33:23.910709	\N
b890385a-22f5-481b-9eb5-8c0df80e55e9	\N	103512a5-8595-4528-b859-210a5021d531	c8dd8b95-c869-4d65-88a3-e7ec3a9f2082	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.949555	2020-10-29 13:33:23.950029	2020-10-29 13:33:23.950029	\N
6bd83bb9-3511-4904-a632-34aa119e1871	\N	103512a5-8595-4528-b859-210a5021d531	f53247bc-7cf1-41a2-b807-7255da660817	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.967605	2020-10-29 13:33:23.967982	2020-10-29 13:33:23.967982	\N
99302cef-4b1e-4340-bfa0-fb0ffac6fdb2	\N	103512a5-8595-4528-b859-210a5021d531	e0d5e0c9-d0c7-43d2-8b70-0405dad45560	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:23.986697	2020-10-29 13:33:23.987113	2020-10-29 13:33:23.987113	\N
19095d74-b764-4552-87d5-dc337468dbd8	\N	\N	53b49b78-0ce9-4cb2-b558-fd5a500a3453	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:24.006644	2020-10-29 13:33:24.007146	2020-10-29 13:33:24.007146	\N
5044f5ed-5efc-4d05-a5cb-61e1d1467381	\N	\N	7f7d800f-3e53-424e-b85d-623fba723a30	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:24.02782	2020-10-29 13:33:24.028361	2020-10-29 13:33:24.028361	\N
d0d07680-a132-44a2-9d5c-07ad60d7a2c0	\N	\N	9b85459c-8d9a-46de-8812-658173d4b5d3	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:24.050187	2020-10-29 13:33:24.050699	2020-10-29 13:33:24.050699	\N
54b95972-140b-481d-87dc-c365f546d71a	\N	\N	20671dff-93fe-43d0-a53e-2e97426c418f	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:24.070841	2020-10-29 13:33:24.071276	2020-10-29 13:33:24.071276	\N
41ffbb98-b79b-44ca-8b7b-8bda750399a3	\N	20671dff-93fe-43d0-a53e-2e97426c418f	c1bad241-8116-4243-aa5d-ed1e2b6488ac	\N	4cb1dc62-e659-46c0-887f-c458ca71ed8f	2020-10-29 13:33:24.090283	2020-10-29 13:33:24.090707	2020-10-29 13:33:24.090707	\N
\.


--
-- TOC entry 4320 (class 0 OID 20998)
-- Dependencies: 209
-- Data for Name: classifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classifications (id, name, external_source_id, external_key, description, seen_at, location, bbox, shape, external_type, created_at, updated_at, deleted_at, uri) FROM stdin;
2319914e-2a3c-45aa-bcdf-2d705a23dabc	Männlich	\N	\N	Male	2020-10-29 13:33:13.692052	\N	\N	\N	\N	2020-10-29 13:33:13.692713	2020-10-29 13:33:13.692713	\N	https://schema.org/Male
2ea159d5-3176-49b7-8e87-a3e640298382	Weiblich	\N	\N	Female	2020-10-29 13:33:13.717497	\N	\N	\N	\N	2020-10-29 13:33:13.717985	2020-10-29 13:33:13.717985	\N	https://schema.org/Female
c67575c7-91c4-426e-b97d-983e5bcc1d22	Montag	\N	\N	\N	2020-10-29 13:33:13.738373	\N	\N	\N	\N	2020-10-29 13:33:13.738851	2020-10-29 13:33:13.738851	\N	https://schema.org/Monday
05737ee1-ee50-4fd2-bdca-17722eeaab09	Dienstag	\N	\N	\N	2020-10-29 13:33:13.760568	\N	\N	\N	\N	2020-10-29 13:33:13.761032	2020-10-29 13:33:13.761032	\N	https://schema.org/Tuesday
5980dc57-5701-4a9a-a584-77f95da8a76c	Mittwoch	\N	\N	\N	2020-10-29 13:33:13.777597	\N	\N	\N	\N	2020-10-29 13:33:13.7781	2020-10-29 13:33:13.7781	\N	https://schema.org/Wednesday
fb8791f0-2fdc-4374-aa4a-523b8246fd7e	Donnerstag	\N	\N	\N	2020-10-29 13:33:13.801776	\N	\N	\N	\N	2020-10-29 13:33:13.802241	2020-10-29 13:33:13.802241	\N	https://schema.org/Thursday
fcdcc46a-48db-4d75-bb5f-88cf1ab931dc	Freitag	\N	\N	\N	2020-10-29 13:33:13.824646	\N	\N	\N	\N	2020-10-29 13:33:13.825118	2020-10-29 13:33:13.825118	\N	https://schema.org/Friday
acb322a9-f0f4-4dca-be13-c9a15fe1f102	Samstag	\N	\N	\N	2020-10-29 13:33:13.840446	\N	\N	\N	\N	2020-10-29 13:33:13.840892	2020-10-29 13:33:13.840892	\N	https://schema.org/Saturday
3b1c24c6-7b9d-42ce-9959-957415d58c19	Sonntag	\N	\N	\N	2020-10-29 13:33:13.856092	\N	\N	\N	\N	2020-10-29 13:33:13.856544	2020-10-29 13:33:13.856544	\N	https://schema.org/Sunday
5831427c-d32c-4a46-abdb-46547e242d04	Januar	\N	\N	\N	2020-10-29 13:33:13.881305	\N	\N	\N	\N	2020-10-29 13:33:13.881767	2020-10-29 13:33:13.881767	\N	\N
9a4a5643-95db-406e-8f0f-b58cab33c6ac	Februar	\N	\N	\N	2020-10-29 13:33:13.906252	\N	\N	\N	\N	2020-10-29 13:33:13.906734	2020-10-29 13:33:13.906734	\N	\N
d466bb3c-ab54-40f3-b9d0-12ab54244916	März	\N	\N	\N	2020-10-29 13:33:13.922593	\N	\N	\N	\N	2020-10-29 13:33:13.9231	2020-10-29 13:33:13.9231	\N	\N
da1e13d5-e79e-43f5-a373-03b5d206178c	April	\N	\N	\N	2020-10-29 13:33:13.938694	\N	\N	\N	\N	2020-10-29 13:33:13.939156	2020-10-29 13:33:13.939156	\N	\N
971795b0-e0cd-49a4-905a-479a09191e75	Mai	\N	\N	\N	2020-10-29 13:33:13.955025	\N	\N	\N	\N	2020-10-29 13:33:13.955576	2020-10-29 13:33:13.955576	\N	\N
56d29600-e8b9-4849-84ae-e7a70b9c3dc7	Juni	\N	\N	\N	2020-10-29 13:33:13.971711	\N	\N	\N	\N	2020-10-29 13:33:13.972172	2020-10-29 13:33:13.972172	\N	\N
53c15801-862e-4224-ab04-5c4fe195a7c8	Juli	\N	\N	\N	2020-10-29 13:33:13.988118	\N	\N	\N	\N	2020-10-29 13:33:13.988616	2020-10-29 13:33:13.988616	\N	\N
0d8d70a1-a263-4305-a5da-a0e62dd8e1bc	August	\N	\N	\N	2020-10-29 13:33:14.00472	\N	\N	\N	\N	2020-10-29 13:33:14.005193	2020-10-29 13:33:14.005193	\N	\N
9d8c9b55-d466-47ae-bfa2-08365fbe2628	September	\N	\N	\N	2020-10-29 13:33:14.02086	\N	\N	\N	\N	2020-10-29 13:33:14.021329	2020-10-29 13:33:14.021329	\N	\N
b8b2a8c1-70cb-4293-94d6-165b2ef6c2fb	Oktober	\N	\N	\N	2020-10-29 13:33:14.037109	\N	\N	\N	\N	2020-10-29 13:33:14.037571	2020-10-29 13:33:14.037571	\N	\N
fd953f02-f98d-41fb-b9d5-0ccce9b7d1e0	November	\N	\N	\N	2020-10-29 13:33:14.05311	\N	\N	\N	\N	2020-10-29 13:33:14.053704	2020-10-29 13:33:14.053704	\N	\N
2d204544-f1a5-4e50-b6b7-878d794f4f12	Dezember	\N	\N	\N	2020-10-29 13:33:14.069387	\N	\N	\N	\N	2020-10-29 13:33:14.069837	2020-10-29 13:33:14.069837	\N	\N
c839a756-ebb4-4c37-8de4-8236e0f74bf9	Tag 1	\N	\N	\N	2020-10-29 13:33:14.089698	\N	\N	\N	\N	2020-10-29 13:33:14.090196	2020-10-29 13:33:14.090196	\N	\N
b3c40195-6b0f-48e6-b6cd-b41bfd667c06	Tag 2	\N	\N	\N	2020-10-29 13:33:14.113291	\N	\N	\N	\N	2020-10-29 13:33:14.113769	2020-10-29 13:33:14.113769	\N	\N
4bf2a820-fa37-42ec-985d-6931bd0bce3f	Web	\N	\N	\N	2020-10-29 13:33:14.132992	\N	\N	\N	\N	2020-10-29 13:33:14.133534	2020-10-29 13:33:14.133534	\N	\N
334e052b-190e-47d7-8790-de872922fb36	Print	\N	\N	\N	2020-10-29 13:33:14.148825	\N	\N	\N	\N	2020-10-29 13:33:14.149269	2020-10-29 13:33:14.149269	\N	\N
3399351d-f234-4db0-b3b5-19da4a8e6949	Social Media	\N	\N	\N	2020-10-29 13:33:14.164636	\N	\N	\N	\N	2020-10-29 13:33:14.165078	2020-10-29 13:33:14.165078	\N	\N
f1d5ea6a-526a-43f1-bb9e-25c076046bcd	description	\N	\N	OutdoorActive	2020-10-29 13:33:14.190537	\N	\N	\N	\N	2020-10-29 13:33:14.191058	2020-10-29 13:33:14.191058	\N	\N
86ff7fd7-8eb9-45f8-b6eb-472507e08eea	text	\N	\N	OutdoorActive	2020-10-29 13:33:14.206312	\N	\N	\N	\N	2020-10-29 13:33:14.206832	2020-10-29 13:33:14.206832	\N	\N
6f4ee8c8-d59b-4932-af71-6c4a32bdd818	directions	\N	\N	OutdoorActive	2020-10-29 13:33:14.222078	\N	\N	\N	\N	2020-10-29 13:33:14.222579	2020-10-29 13:33:14.222579	\N	\N
9952c3bf-44eb-4044-a551-1e3c57d6087b	directions_public_transport	\N	\N	OutdoorActive	2020-10-29 13:33:14.237917	\N	\N	\N	\N	2020-10-29 13:33:14.238338	2020-10-29 13:33:14.238338	\N	\N
3adc1955-ce5d-4d3f-a341-777e05b1a1af	parking	\N	\N	OutdoorActive	2020-10-29 13:33:14.253633	\N	\N	\N	\N	2020-10-29 13:33:14.254034	2020-10-29 13:33:14.254034	\N	\N
2c577c0b-04e7-4f9b-8f68-d6c47749cd05	hours_available	\N	\N	OutdoorActive	2020-10-29 13:33:14.269601	\N	\N	\N	\N	2020-10-29 13:33:14.270088	2020-10-29 13:33:14.270088	\N	\N
0e82891a-c710-45ba-a330-ca3d4c43e33d	price	\N	\N	OutdoorActive	2020-10-29 13:33:14.285819	\N	\N	\N	\N	2020-10-29 13:33:14.28626	2020-10-29 13:33:14.28626	\N	\N
b6c71400-758a-48c7-b22d-d07452da20ad	instructions	\N	\N	OutdoorActive	2020-10-29 13:33:14.302139	\N	\N	\N	\N	2020-10-29 13:33:14.302619	2020-10-29 13:33:14.302619	\N	\N
4caad905-e9d8-4925-9b8a-996a9ebb0e97	safety_instructions	\N	\N	OutdoorActive	2020-10-29 13:33:14.318143	\N	\N	\N	\N	2020-10-29 13:33:14.318619	2020-10-29 13:33:14.318619	\N	\N
0785e13b-7455-4dc3-892d-10c9bd433e48	equipment	\N	\N	OutdoorActive	2020-10-29 13:33:14.334048	\N	\N	\N	\N	2020-10-29 13:33:14.334533	2020-10-29 13:33:14.334533	\N	\N
ce9bac8b-3ba4-411b-a249-45403f7e3bb1	suggestion	\N	\N	OutdoorActive	2020-10-29 13:33:14.350904	\N	\N	\N	\N	2020-10-29 13:33:14.351366	2020-10-29 13:33:14.351366	\N	\N
e5ac3b70-6c13-45b0-93f4-77384ab89173	additional_information	\N	\N	OutdoorActive	2020-10-29 13:33:14.36693	\N	\N	\N	\N	2020-10-29 13:33:14.367428	2020-10-29 13:33:14.367428	\N	\N
bc60baea-dc29-4aa1-ba2b-f01f7ef561ce	AdditionalService	\N	\N	Feratel	2020-10-29 13:33:14.39041	\N	\N	\N	\N	2020-10-29 13:33:14.390906	2020-10-29 13:33:14.390906	\N	\N
7a82f233-9aed-4768-8165-4b76269e10e7	CurrentInformation	\N	\N	Feratel	2020-10-29 13:33:14.406494	\N	\N	\N	\N	2020-10-29 13:33:14.40694	2020-10-29 13:33:14.40694	\N	\N
bcf89a04-dc43-40c7-8680-90e0becc504b	EventHeader	\N	\N	Feratel	2020-10-29 13:33:14.42227	\N	\N	\N	\N	2020-10-29 13:33:14.422777	2020-10-29 13:33:14.422777	\N	\N
c56ae8b9-3deb-4ac2-ae9e-13daa31a0172	EventHeaderShort	\N	\N	Feratel	2020-10-29 13:33:14.438604	\N	\N	\N	\N	2020-10-29 13:33:14.439084	2020-10-29 13:33:14.439084	\N	\N
a269d142-2339-4636-b733-058848c0c811	GuestCardClassification	\N	\N	Feratel	2020-10-29 13:33:14.454591	\N	\N	\N	\N	2020-10-29 13:33:14.455084	2020-10-29 13:33:14.455084	\N	\N
453f02a6-3dbf-4ac0-a8f1-61b24057a7d8	InfrastructureLong	\N	\N	Feratel	2020-10-29 13:33:14.470246	\N	\N	\N	\N	2020-10-29 13:33:14.470712	2020-10-29 13:33:14.470712	\N	\N
9c4b0df9-d9d9-48d6-92ab-387d68e6b4f3	InfrastructureOpeningTimes	\N	\N	Feratel	2020-10-29 13:33:14.486503	\N	\N	\N	\N	2020-10-29 13:33:14.486962	2020-10-29 13:33:14.486962	\N	\N
74044c4e-6df8-419d-9532-4a5fed8310dd	InfrastructurePriceInfo	\N	\N	Feratel	2020-10-29 13:33:14.502444	\N	\N	\N	\N	2020-10-29 13:33:14.502952	2020-10-29 13:33:14.502952	\N	\N
d3c4c166-18f3-45c8-9ffe-cef16a3ddd66	InfrastructureShort	\N	\N	Feratel	2020-10-29 13:33:14.519193	\N	\N	\N	\N	2020-10-29 13:33:14.519656	2020-10-29 13:33:14.519656	\N	\N
a58d8d9c-d114-47ec-997e-c48b2bb7791d	Package	\N	\N	Feratel	2020-10-29 13:33:14.535095	\N	\N	\N	\N	2020-10-29 13:33:14.535541	2020-10-29 13:33:14.535541	\N	\N
3f1e1acb-835e-4d34-8e74-2e6b4e788a4c	PackageContentLong	\N	\N	Feratel	2020-10-29 13:33:14.551005	\N	\N	\N	\N	2020-10-29 13:33:14.551447	2020-10-29 13:33:14.551447	\N	\N
a4c8bd0a-d375-4b4a-844a-afe278e9ee44	PackageShortText	\N	\N	Feratel	2020-10-29 13:33:14.566799	\N	\N	\N	\N	2020-10-29 13:33:14.567252	2020-10-29 13:33:14.567252	\N	\N
8d8bd95f-960e-48ef-a26e-264f4600f20f	ProductDescription	\N	\N	Feratel	2020-10-29 13:33:14.582256	\N	\N	\N	\N	2020-10-29 13:33:14.582765	2020-10-29 13:33:14.582765	\N	\N
250d7dfd-d4a0-49c2-9cc1-e2cdfa604c87	SEOKeywords	\N	\N	Feratel	2020-10-29 13:33:14.597947	\N	\N	\N	\N	2020-10-29 13:33:14.598383	2020-10-29 13:33:14.598383	\N	\N
eb3de79a-d02e-4e48-9b6c-b8e176ad63da	ShopItemDescription	\N	\N	Feratel	2020-10-29 13:33:14.613559	\N	\N	\N	\N	2020-10-29 13:33:14.613999	2020-10-29 13:33:14.613999	\N	\N
dd9bfc58-8e25-4399-8916-2a93f141a9ef	ServiceDescription	\N	\N	Feratel	2020-10-29 13:33:14.629363	\N	\N	\N	\N	2020-10-29 13:33:14.629867	2020-10-29 13:33:14.629867	\N	\N
3ab2371e-1d6f-450c-9325-5ccde4f7e174	ServiceProviderArrivalVoucher	\N	\N	Feratel	2020-10-29 13:33:14.652973	\N	\N	\N	\N	2020-10-29 13:33:14.653426	2020-10-29 13:33:14.653426	\N	\N
98f1e426-8148-4ada-a786-3f227b4dbb21	ServiceProviderConditions	\N	\N	Feratel	2020-10-29 13:33:14.669328	\N	\N	\N	\N	2020-10-29 13:33:14.669808	2020-10-29 13:33:14.669808	\N	\N
0b212ccb-9524-4296-8160-61a01c1de449	ServiceProviderDescription	\N	\N	Feratel	2020-10-29 13:33:14.685141	\N	\N	\N	\N	2020-10-29 13:33:14.685739	2020-10-29 13:33:14.685739	\N	\N
64bdc356-42f0-4d7c-9038-cc34f4a76124	Top-Event	\N	\N	\N	2020-10-29 13:33:14.723651	\N	\N	\N	\N	2020-10-29 13:33:14.724173	2020-10-29 13:33:14.724173	\N	\N
c943e9f8-d342-439f-b2fc-0cf311ad8cc8	Local	\N	\N	\N	2020-10-29 13:33:14.740778	\N	\N	\N	\N	2020-10-29 13:33:14.741351	2020-10-29 13:33:14.741351	\N	\N
4ccfb52b-a8f5-4e06-98a2-bd5288109cd9	Town	\N	\N	\N	2020-10-29 13:33:14.758307	\N	\N	\N	\N	2020-10-29 13:33:14.758845	2020-10-29 13:33:14.758845	\N	\N
b9bc7a46-bbd7-42ab-8b36-e090d332035e	Region	\N	\N	\N	2020-10-29 13:33:14.782472	\N	\N	\N	\N	2020-10-29 13:33:14.782996	2020-10-29 13:33:14.782996	\N	\N
382699cf-963e-4c4b-b7ed-501ce0161788	Subregion	\N	\N	\N	2020-10-29 13:33:14.800538	\N	\N	\N	\N	2020-10-29 13:33:14.801061	2020-10-29 13:33:14.801061	\N	\N
525d643e-3b56-4ea1-9d18-c87b35a9cecf	Country	\N	\N	\N	2020-10-29 13:33:14.818389	\N	\N	\N	\N	2020-10-29 13:33:14.818887	2020-10-29 13:33:14.818887	\N	\N
ac08fc85-f0e4-415e-a03f-525f6333611d	Aktiv	\N	\N	\N	2020-10-29 13:33:14.853437	\N	\N	\N	\N	2020-10-29 13:33:14.855235	2020-10-29 13:33:14.855235	\N	\N
b1260eca-e131-460f-8b07-c51e5d1f7360	Inaktiv	\N	\N	\N	2020-10-29 13:33:14.883797	\N	\N	\N	\N	2020-10-29 13:33:14.884867	2020-10-29 13:33:14.884867	\N	\N
a3226808-3834-4701-818c-7089af89d41c	Gelöscht	\N	\N	\N	2020-10-29 13:33:14.912877	\N	\N	\N	\N	2020-10-29 13:33:14.913892	2020-10-29 13:33:14.913892	\N	\N
42908ee8-e23c-403c-bea9-828b5f1ec831	Aktiv	\N	\N	\N	2020-10-29 13:33:14.951068	\N	\N	\N	\N	2020-10-29 13:33:14.951951	2020-10-29 13:33:14.951951	\N	\N
a4912fac-b99d-41f5-a48b-3acf7952ea01	Inaktiv	\N	\N	\N	2020-10-29 13:33:14.995722	\N	\N	\N	\N	2020-10-29 13:33:14.996283	2020-10-29 13:33:14.996283	\N	\N
7b3dc3d0-f7b0-420a-abdb-a60457c10645	Buchbar	\N	\N	\N	2020-10-29 13:33:15.017402	\N	\N	\N	\N	2020-10-29 13:33:15.017857	2020-10-29 13:33:15.017857	\N	\N
411651a1-3e39-4229-b043-b5a3c779384d	Nicht Buchbar	\N	\N	\N	2020-10-29 13:33:15.033672	\N	\N	\N	\N	2020-10-29 13:33:15.0342	2020-10-29 13:33:15.0342	\N	\N
8f57729a-4bb9-43e7-8a7d-41f93aad0f83	Preis pro Person	\N	\N	\N	2020-10-29 13:33:15.054751	\N	\N	\N	\N	2020-10-29 13:33:15.05529	2020-10-29 13:33:15.05529	\N	\N
4f4e4790-58bf-4ee9-a831-6d3e4f606e52	Preis pro Package	\N	\N	\N	2020-10-29 13:33:15.071805	\N	\N	\N	\N	2020-10-29 13:33:15.07232	2020-10-29 13:33:15.07232	\N	\N
a47be155-5cc7-4a14-aef6-15254cd66c45	Andorra	\N	\N	\N	2020-10-29 13:33:15.093684	\N	\N	\N	\N	2020-10-29 13:33:15.094224	2020-10-29 13:33:15.094224	\N	\N
a6f9503f-c6e4-4487-92d2-4aaf6f996720	Dänemark	\N	\N	\N	2020-10-29 13:33:15.115654	\N	\N	\N	\N	2020-10-29 13:33:15.11623	2020-10-29 13:33:15.11623	\N	\N
9d7cb346-b77b-49b0-84df-5710eb79c3de	Deutschland	\N	\N	\N	2020-10-29 13:33:15.1326	\N	\N	\N	\N	2020-10-29 13:33:15.133106	2020-10-29 13:33:15.133106	\N	\N
c35800f5-a15a-4d42-8faa-1f654bf36889	Frankreich	\N	\N	\N	2020-10-29 13:33:15.149459	\N	\N	\N	\N	2020-10-29 13:33:15.14993	2020-10-29 13:33:15.14993	\N	\N
82ded662-bc46-43bb-80d0-6e9a539ece86	Italien	\N	\N	\N	2020-10-29 13:33:15.166285	\N	\N	\N	\N	2020-10-29 13:33:15.166727	2020-10-29 13:33:15.166727	\N	\N
ddb17ae8-387f-4990-ab83-b88150b2bdb6	Kroatien	\N	\N	\N	2020-10-29 13:33:15.182713	\N	\N	\N	\N	2020-10-29 13:33:15.183182	2020-10-29 13:33:15.183182	\N	\N
cda9e956-eac6-46cc-ab91-4ae953da54a2	Liechtenstein	\N	\N	\N	2020-10-29 13:33:15.199969	\N	\N	\N	\N	2020-10-29 13:33:15.200482	2020-10-29 13:33:15.200482	\N	\N
c6c56c3a-df25-4062-b71b-b4744b3a39f7	Österreich	\N	\N	\N	2020-10-29 13:33:15.221041	\N	\N	\N	\N	2020-10-29 13:33:15.221695	2020-10-29 13:33:15.221695	\N	\N
cf42f40d-1f84-4d6f-93c0-ab6ed8a4beb1	Polen	\N	\N	\N	2020-10-29 13:33:15.241611	\N	\N	\N	\N	2020-10-29 13:33:15.242091	2020-10-29 13:33:15.242091	\N	\N
85b3f8a3-95a2-40ae-9ab4-38b5e8ac3c84	Portugal	\N	\N	\N	2020-10-29 13:33:15.25839	\N	\N	\N	\N	2020-10-29 13:33:15.258899	2020-10-29 13:33:15.258899	\N	\N
8ba65e4f-f382-4d38-9d04-dbacc3857847	Slowakei	\N	\N	\N	2020-10-29 13:33:15.275638	\N	\N	\N	\N	2020-10-29 13:33:15.276188	2020-10-29 13:33:15.276188	\N	\N
f07b3691-4fbc-4b41-9f85-af1f80c0bfdf	Slowenien	\N	\N	\N	2020-10-29 13:33:15.29281	\N	\N	\N	\N	2020-10-29 13:33:15.293335	2020-10-29 13:33:15.293335	\N	\N
514da42f-bc3a-43c9-9e5b-7d1ad48127fb	Schweiz	\N	\N	\N	2020-10-29 13:33:15.309704	\N	\N	\N	\N	2020-10-29 13:33:15.310211	2020-10-29 13:33:15.310211	\N	\N
be372422-ee0e-4447-ad28-7ead7d2bcde5	Schweden	\N	\N	\N	2020-10-29 13:33:15.332893	\N	\N	\N	\N	2020-10-29 13:33:15.333491	2020-10-29 13:33:15.333491	\N	\N
729b6513-d6e7-4ac5-beb4-6f04b06431a3	Spanien	\N	\N	\N	2020-10-29 13:33:15.350832	\N	\N	\N	\N	2020-10-29 13:33:15.351415	2020-10-29 13:33:15.351415	\N	\N
42824017-ceaa-4337-9a33-9e39457bf76b	Tschechien	\N	\N	\N	2020-10-29 13:33:15.367338	\N	\N	\N	\N	2020-10-29 13:33:15.367986	2020-10-29 13:33:15.367986	\N	\N
db4fca96-2e1e-4b8b-a2c7-96d3931abe64	Ungarn	\N	\N	\N	2020-10-29 13:33:15.385142	\N	\N	\N	\N	2020-10-29 13:33:15.385716	2020-10-29 13:33:15.385716	\N	\N
43443479-d28b-41c1-9851-f5fb5157a6ac	AF	\N	\N	Afghanistan	2020-10-29 13:33:15.406432	\N	\N	\N	\N	2020-10-29 13:33:15.406926	2020-10-29 13:33:15.406926	\N	\N
4d8bca72-e829-4193-a217-d8bdce746e44	EG	\N	\N	Ägypten	2020-10-29 13:33:15.424067	\N	\N	\N	\N	2020-10-29 13:33:15.424662	2020-10-29 13:33:15.424662	\N	\N
28891271-1dbe-4983-8ae0-d2b02a6fd50f	AL	\N	\N	Albanien	2020-10-29 13:33:15.445634	\N	\N	\N	\N	2020-10-29 13:33:15.44615	2020-10-29 13:33:15.44615	\N	\N
d363ad8f-d522-43c6-b739-9a0df1668a71	DZ	\N	\N	Algerien	2020-10-29 13:33:15.465231	\N	\N	\N	\N	2020-10-29 13:33:15.465776	2020-10-29 13:33:15.465776	\N	\N
e2af3d12-3559-4962-bec9-bc6dcb6d6638	VI	\N	\N	Amerikanische Jungferninsel	2020-10-29 13:33:15.482184	\N	\N	\N	\N	2020-10-29 13:33:15.482723	2020-10-29 13:33:15.482723	\N	\N
b3a09db9-0f8d-4d61-a715-a70ed7e5b155	UM	\N	\N	Amerikanische Überseeinseln, kleinere	2020-10-29 13:33:15.503836	\N	\N	\N	\N	2020-10-29 13:33:15.504368	2020-10-29 13:33:15.504368	\N	\N
42aac85c-3d89-4c01-a22e-5eb2b0b443bf	AS	\N	\N	Amerikanisch-Samoa	2020-10-29 13:33:15.521403	\N	\N	\N	\N	2020-10-29 13:33:15.521968	2020-10-29 13:33:15.521968	\N	\N
81c7a1b6-597b-4d5e-9746-514fdea9d35e	AD	\N	\N	Andorra, Fürstentum	2020-10-29 13:33:15.542686	\N	\N	\N	\N	2020-10-29 13:33:15.543278	2020-10-29 13:33:15.543278	\N	\N
7a4aaaf9-8949-49aa-91b6-dd1e4b7493e9	AO	\N	\N	Angola	2020-10-29 13:33:15.55998	\N	\N	\N	\N	2020-10-29 13:33:15.560531	2020-10-29 13:33:15.560531	\N	\N
aaabe993-e798-4fdc-b8a3-645f96a412a4	AI	\N	\N	Anguilla	2020-10-29 13:33:15.576905	\N	\N	\N	\N	2020-10-29 13:33:15.577461	2020-10-29 13:33:15.577461	\N	\N
2e278c8c-4b1b-4324-8148-d17ae9e69d69	AG	\N	\N	Antigua und Barbuda	2020-10-29 13:33:15.594315	\N	\N	\N	\N	2020-10-29 13:33:15.594866	2020-10-29 13:33:15.594866	\N	\N
922f506c-182e-4846-9b11-c413fa86af06	GQ	\N	\N	Äquatorialguinea	2020-10-29 13:33:15.612344	\N	\N	\N	\N	2020-10-29 13:33:15.612798	2020-10-29 13:33:15.612798	\N	\N
e35c545e-45ef-4a0d-9922-67865edda02b	AR	\N	\N	Argentinien	2020-10-29 13:33:15.630075	\N	\N	\N	\N	2020-10-29 13:33:15.6306	2020-10-29 13:33:15.6306	\N	\N
bb4b3f4d-0ded-46e0-abbb-56053a2c75e9	AM	\N	\N	Armenien	2020-10-29 13:33:15.648817	\N	\N	\N	\N	2020-10-29 13:33:15.653556	2020-10-29 13:33:15.653556	\N	\N
44e460e3-77c0-4458-bb19-5e934181b50a	AW	\N	\N	Aruba	2020-10-29 13:33:15.671235	\N	\N	\N	\N	2020-10-29 13:33:15.671739	2020-10-29 13:33:15.671739	\N	\N
9e97859d-f6af-45eb-86a9-e420c100f873	AZ	\N	\N	Aserbaidschan	2020-10-29 13:33:15.68904	\N	\N	\N	\N	2020-10-29 13:33:15.689553	2020-10-29 13:33:15.689553	\N	\N
d41300b2-9245-4f63-bc26-ddc972afec4b	ET	\N	\N	Äthiopien	2020-10-29 13:33:15.706639	\N	\N	\N	\N	2020-10-29 13:33:15.707312	2020-10-29 13:33:15.707312	\N	\N
7498a2c5-937f-41fb-b3f0-c8519b0931dd	AU	\N	\N	Australien	2020-10-29 13:33:15.724484	\N	\N	\N	\N	2020-10-29 13:33:15.72505	2020-10-29 13:33:15.72505	\N	\N
20fb07d1-4225-4216-b4b8-7f7c5c9438eb	BS	\N	\N	Bahamas	2020-10-29 13:33:15.741732	\N	\N	\N	\N	2020-10-29 13:33:15.742213	2020-10-29 13:33:15.742213	\N	\N
7b8642eb-5787-4979-97be-fd2a1e5ed904	BH	\N	\N	Bahrain	2020-10-29 13:33:15.763271	\N	\N	\N	\N	2020-10-29 13:33:15.763896	2020-10-29 13:33:15.763896	\N	\N
47117b23-8af6-4bd5-9bf1-14954602930f	BD	\N	\N	Bangladesch	2020-10-29 13:33:15.781786	\N	\N	\N	\N	2020-10-29 13:33:15.782345	2020-10-29 13:33:15.782345	\N	\N
e145efd3-4ddb-4ea0-b381-70145bfa38c4	BB	\N	\N	Barbados	2020-10-29 13:33:15.800514	\N	\N	\N	\N	2020-10-29 13:33:15.801051	2020-10-29 13:33:15.801051	\N	\N
89a54aab-002e-4057-93a5-01defa05f8df	BE	\N	\N	Belgien	2020-10-29 13:33:15.819669	\N	\N	\N	\N	2020-10-29 13:33:15.820221	2020-10-29 13:33:15.820221	\N	\N
3c5f6297-f693-496d-adca-d4cc71680294	BZ	\N	\N	Belize	2020-10-29 13:33:15.856456	\N	\N	\N	\N	2020-10-29 13:33:15.857599	2020-10-29 13:33:15.857599	\N	\N
efec6b7d-c806-4d16-8411-6799f978abd0	BJ	\N	\N	Benin	2020-10-29 13:33:15.889539	\N	\N	\N	\N	2020-10-29 13:33:15.890809	2020-10-29 13:33:15.890809	\N	\N
ded156fe-6f70-4382-be09-7d234d2c6b96	BM	\N	\N	Bermudas	2020-10-29 13:33:15.917424	\N	\N	\N	\N	2020-10-29 13:33:15.918348	2020-10-29 13:33:15.918348	\N	\N
b5a48f63-0d2b-4adc-9a5e-790899705b1f	BT	\N	\N	Bhutan, Königreich	2020-10-29 13:33:15.950595	\N	\N	\N	\N	2020-10-29 13:33:15.951555	2020-10-29 13:33:15.951555	\N	\N
be63489c-9dda-4f24-9e71-034726d6e36f	BO	\N	\N	Bolivien	2020-10-29 13:33:15.996064	\N	\N	\N	\N	2020-10-29 13:33:15.996651	2020-10-29 13:33:15.996651	\N	\N
b8ed6a10-0dfe-4d97-831c-05fc9f5373f0	BA	\N	\N	Bosnien-Herzegowina	2020-10-29 13:33:16.013115	\N	\N	\N	\N	2020-10-29 13:33:16.013613	2020-10-29 13:33:16.013613	\N	\N
232379cc-ddd7-4daa-8be9-8f62ee22cb52	BW	\N	\N	Botsuana	2020-10-29 13:33:16.03017	\N	\N	\N	\N	2020-10-29 13:33:16.030707	2020-10-29 13:33:16.030707	\N	\N
1c2601be-1ac3-4061-87e1-472d353e862b	BV	\N	\N	Bouvetinseln	2020-10-29 13:33:16.047416	\N	\N	\N	\N	2020-10-29 13:33:16.048061	2020-10-29 13:33:16.048061	\N	\N
c77087a4-e18c-4661-bd3d-daa61dd08d2c	BR	\N	\N	Brasilien	2020-10-29 13:33:16.064721	\N	\N	\N	\N	2020-10-29 13:33:16.065203	2020-10-29 13:33:16.065203	\N	\N
a380b06e-a462-46a5-937d-9ea29b783206	VG	\N	\N	Britische Jungferninseln	2020-10-29 13:33:16.080991	\N	\N	\N	\N	2020-10-29 13:33:16.081476	2020-10-29 13:33:16.081476	\N	\N
640df930-589b-4a98-8a6a-06be0c74b358	IO	\N	\N	Britisches Territorium im Indischen Ozean	2020-10-29 13:33:16.098211	\N	\N	\N	\N	2020-10-29 13:33:16.098702	2020-10-29 13:33:16.098702	\N	\N
6cd5f3f6-43a0-4f62-bba1-111986f7ea41	BN	\N	\N	Brunei Darussalam	2020-10-29 13:33:16.138287	\N	\N	\N	\N	2020-10-29 13:33:16.139274	2020-10-29 13:33:16.139274	\N	\N
d4afc1df-7878-4809-b3a4-569963f909e0	BG	\N	\N	Bulgarien	2020-10-29 13:33:16.160021	\N	\N	\N	\N	2020-10-29 13:33:16.160535	2020-10-29 13:33:16.160535	\N	\N
f66c8027-81dc-4f45-b55e-bd6f27465e2f	YU	\N	\N	Bundesrepublik Yugoslawien	2020-10-29 13:33:16.177843	\N	\N	\N	\N	2020-10-29 13:33:16.178316	2020-10-29 13:33:16.178316	\N	\N
7b92be52-1ac1-4528-8264-9b1abfb5dd35	BF	\N	\N	Burkina Faso (ehem Obervolta)	2020-10-29 13:33:16.195428	\N	\N	\N	\N	2020-10-29 13:33:16.195955	2020-10-29 13:33:16.195955	\N	\N
21dcc367-843c-4590-b5d6-6f7fa12d0f4e	BI	\N	\N	Burundi	2020-10-29 13:33:16.213145	\N	\N	\N	\N	2020-10-29 13:33:16.213586	2020-10-29 13:33:16.213586	\N	\N
bc10ef19-c189-4e73-a717-6051b26724a5	CL	\N	\N	Chile	2020-10-29 13:33:16.26176	\N	\N	\N	\N	2020-10-29 13:33:16.263561	2020-10-29 13:33:16.263561	\N	\N
de2394ab-2bc8-4d2b-9f12-7f669e8369c8	TW	\N	\N	China, Republik (Taiwan)	2020-10-29 13:33:16.31187	\N	\N	\N	\N	2020-10-29 13:33:16.312721	2020-10-29 13:33:16.312721	\N	\N
a87deb12-d67a-47bb-b398-512c8830aca0	CN	\N	\N	China, Volksrepublik	2020-10-29 13:33:16.337933	\N	\N	\N	\N	2020-10-29 13:33:16.338743	2020-10-29 13:33:16.338743	\N	\N
decc1d7c-0a73-4d22-bc69-f9cfbbb6f8c3	CK	\N	\N	Cookinseln	2020-10-29 13:33:16.363984	\N	\N	\N	\N	2020-10-29 13:33:16.364807	2020-10-29 13:33:16.364807	\N	\N
72a9d447-234a-4c9d-8022-94562fb36fb4	CR	\N	\N	Costa Rica	2020-10-29 13:33:16.389719	\N	\N	\N	\N	2020-10-29 13:33:16.390505	2020-10-29 13:33:16.390505	\N	\N
5d248f25-9c3b-49bf-b30b-d356fc4516b5	DK	\N	\N	Dänemark	2020-10-29 13:33:16.415676	\N	\N	\N	\N	2020-10-29 13:33:16.416531	2020-10-29 13:33:16.416531	\N	\N
7c3a41ba-c724-4922-9daa-b2dce01223fe	DE	\N	\N	Deutschland	2020-10-29 13:33:16.446541	\N	\N	\N	\N	2020-10-29 13:33:16.447428	2020-10-29 13:33:16.447428	\N	\N
a9e74040-0163-4af6-8e6f-4a19591a3f35	DM	\N	\N	Dominica	2020-10-29 13:33:16.471864	\N	\N	\N	\N	2020-10-29 13:33:16.472666	2020-10-29 13:33:16.472666	\N	\N
ac556065-421c-4f84-bb6c-bb4a500ea93f	DO	\N	\N	Dominikanische Republik	2020-10-29 13:33:16.495815	\N	\N	\N	\N	2020-10-29 13:33:16.496332	2020-10-29 13:33:16.496332	\N	\N
97650f3a-2640-47d8-a2d0-2d150ee75a96	DJ	\N	\N	Dschibuti	2020-10-29 13:33:16.512809	\N	\N	\N	\N	2020-10-29 13:33:16.513202	2020-10-29 13:33:16.513202	\N	\N
0ebe6f08-280e-40d8-9303-43f5283e2609	EC	\N	\N	Ecuador	2020-10-29 13:33:16.527988	\N	\N	\N	\N	2020-10-29 13:33:16.528392	2020-10-29 13:33:16.528392	\N	\N
708e5106-b63a-44d1-acb5-b991219f9e3d	SV	\N	\N	El Salvador	2020-10-29 13:33:16.543233	\N	\N	\N	\N	2020-10-29 13:33:16.543571	2020-10-29 13:33:16.543571	\N	\N
e3ed2b6a-422c-42e0-b672-f397d391ce0c	CI	\N	\N	Elfenbeinküste (Cote dlvoire)	2020-10-29 13:33:16.558973	\N	\N	\N	\N	2020-10-29 13:33:16.559459	2020-10-29 13:33:16.559459	\N	\N
1c691122-2993-471e-8092-013e319880dc	ER	\N	\N	Eritrea, Republik	2020-10-29 13:33:16.575364	\N	\N	\N	\N	2020-10-29 13:33:16.575865	2020-10-29 13:33:16.575865	\N	\N
ae7a08b7-452c-42f5-8116-331823a4f05c	EE	\N	\N	Estland	2020-10-29 13:33:16.591948	\N	\N	\N	\N	2020-10-29 13:33:16.59245	2020-10-29 13:33:16.59245	\N	\N
2471d231-f6c5-4e9c-a711-b085a06903e9	FK	\N	\N	Falkland Inseln (Islas Malvinas)	2020-10-29 13:33:16.608918	\N	\N	\N	\N	2020-10-29 13:33:16.609394	2020-10-29 13:33:16.609394	\N	\N
7b8ff75a-b699-466f-bc79-563de6837f11	FO	\N	\N	Färöer	2020-10-29 13:33:16.626052	\N	\N	\N	\N	2020-10-29 13:33:16.626501	2020-10-29 13:33:16.626501	\N	\N
375f827a-332d-47a0-9013-46363ee4557c	FJ	\N	\N	Fidschi	2020-10-29 13:33:16.642947	\N	\N	\N	\N	2020-10-29 13:33:16.643325	2020-10-29 13:33:16.643325	\N	\N
3bacfedd-9eed-49ed-99c9-0823cf59c9ef	FI	\N	\N	Finnland	2020-10-29 13:33:16.658718	\N	\N	\N	\N	2020-10-29 13:33:16.659071	2020-10-29 13:33:16.659071	\N	\N
0133afed-0cb6-4697-a729-e0c1a3ff8bc2	FR	\N	\N	Frankreich	2020-10-29 13:33:16.673676	\N	\N	\N	\N	2020-10-29 13:33:16.674053	2020-10-29 13:33:16.674053	\N	\N
90c8c50a-b4ec-4143-b637-3d9e75518be9	TF	\N	\N	Französische Südgebiete	2020-10-29 13:33:16.688693	\N	\N	\N	\N	2020-10-29 13:33:16.689061	2020-10-29 13:33:16.689061	\N	\N
57d2afef-9fd2-4a4a-a996-d4a86f36abaa	GF	\N	\N	Französisch-Guayana	2020-10-29 13:33:16.707475	\N	\N	\N	\N	2020-10-29 13:33:16.707845	2020-10-29 13:33:16.707845	\N	\N
9fc19cae-097c-4770-bc7e-73a1f9d15c4e	PF	\N	\N	Französisch-Polynesien	2020-10-29 13:33:16.72365	\N	\N	\N	\N	2020-10-29 13:33:16.724047	2020-10-29 13:33:16.724047	\N	\N
7f8e17a2-548b-4d4f-938e-0dc3d4b49782	GA	\N	\N	Gabun	2020-10-29 13:33:16.739765	\N	\N	\N	\N	2020-10-29 13:33:16.740213	2020-10-29 13:33:16.740213	\N	\N
83b9638e-fe6d-40c4-85e4-30c5dcc9881a	GM	\N	\N	Gambia	2020-10-29 13:33:16.756433	\N	\N	\N	\N	2020-10-29 13:33:16.756877	2020-10-29 13:33:16.756877	\N	\N
61e369da-3c06-4123-93b1-4e485a25b1b7	GE	\N	\N	Georgien	2020-10-29 13:33:16.772866	\N	\N	\N	\N	2020-10-29 13:33:16.773297	2020-10-29 13:33:16.773297	\N	\N
aecfa6ad-f932-47df-bcd0-b4eec9f9bf08	GH	\N	\N	Ghana	2020-10-29 13:33:16.788967	\N	\N	\N	\N	2020-10-29 13:33:16.789437	2020-10-29 13:33:16.789437	\N	\N
e6f4c99a-7b2f-4891-b39c-d5ae4fd0dfb6	GI	\N	\N	Gibraltar	2020-10-29 13:33:16.805394	\N	\N	\N	\N	2020-10-29 13:33:16.805851	2020-10-29 13:33:16.805851	\N	\N
6fa9b292-1397-4b30-a1d1-96cd2e51b19b	GD	\N	\N	Grenada	2020-10-29 13:33:16.822179	\N	\N	\N	\N	2020-10-29 13:33:16.822593	2020-10-29 13:33:16.822593	\N	\N
d07fbc3a-a573-4c35-9089-fa08e3661248	GR	\N	\N	Griechenland	2020-10-29 13:33:16.837723	\N	\N	\N	\N	2020-10-29 13:33:16.838089	2020-10-29 13:33:16.838089	\N	\N
648d1b55-77c6-4406-8c48-bbc40b27796c	GL	\N	\N	Grönland	2020-10-29 13:33:16.884971	\N	\N	\N	\N	2020-10-29 13:33:16.886742	2020-10-29 13:33:16.886742	\N	\N
9a27872c-0741-4dbd-8230-c9674b7cc005	GP	\N	\N	Guadeloupe	2020-10-29 13:33:16.918496	\N	\N	\N	\N	2020-10-29 13:33:16.919107	2020-10-29 13:33:16.919107	\N	\N
3d3cc570-4251-432c-b588-04ef0d1c7b58	GU	\N	\N	Guam	2020-10-29 13:33:16.940339	\N	\N	\N	\N	2020-10-29 13:33:16.941038	2020-10-29 13:33:16.941038	\N	\N
4719bd5a-0330-47b6-8c4b-7b0ed19c76fd	GT	\N	\N	Guatemala	2020-10-29 13:33:16.962721	\N	\N	\N	\N	2020-10-29 13:33:16.96338	2020-10-29 13:33:16.96338	\N	\N
3f6cfe36-0dbf-4a26-be6a-0040aedff732	GG	\N	\N	Guernsey	2020-10-29 13:33:17.012035	\N	\N	\N	\N	2020-10-29 13:33:17.013829	2020-10-29 13:33:17.013829	\N	\N
313e3625-6023-463a-a9ac-2bcf1973bc4d	GN	\N	\N	Guinea	2020-10-29 13:33:17.039371	\N	\N	\N	\N	2020-10-29 13:33:17.039984	2020-10-29 13:33:17.039984	\N	\N
42b6eba3-f7f6-4171-a238-917ef1b8dcc0	GW	\N	\N	Guinea-Bissau	2020-10-29 13:33:17.057833	\N	\N	\N	\N	2020-10-29 13:33:17.058366	2020-10-29 13:33:17.058366	\N	\N
b64d97dc-91cb-41a0-b0ab-c6e07a21c092	GY	\N	\N	Guyana, Kooperative Republik	2020-10-29 13:33:17.086243	\N	\N	\N	\N	2020-10-29 13:33:17.086867	2020-10-29 13:33:17.086867	\N	\N
345c8b73-0f57-49e5-b9d3-481fa04b3b57	HT	\N	\N	Haiti	2020-10-29 13:33:17.106123	\N	\N	\N	\N	2020-10-29 13:33:17.106735	2020-10-29 13:33:17.106735	\N	\N
bac99b97-b615-4267-88c4-a4923be21f7a	HM	\N	\N	Heart und McDonaldinseln	2020-10-29 13:33:17.126817	\N	\N	\N	\N	2020-10-29 13:33:17.127433	2020-10-29 13:33:17.127433	\N	\N
94f51c3c-9ffb-40c3-b15e-ba3737073fde	HN	\N	\N	Honduras	2020-10-29 13:33:17.14726	\N	\N	\N	\N	2020-10-29 13:33:17.147823	2020-10-29 13:33:17.147823	\N	\N
6ac01816-daba-4142-9fd2-066986099a45	HK	\N	\N	Hongkong	2020-10-29 13:33:17.171672	\N	\N	\N	\N	2020-10-29 13:33:17.172314	2020-10-29 13:33:17.172314	\N	\N
930efa88-53e3-4c0b-bf33-bb35189be439	IN	\N	\N	Indien	2020-10-29 13:33:17.191937	\N	\N	\N	\N	2020-10-29 13:33:17.19254	2020-10-29 13:33:17.19254	\N	\N
ac381a0a-52cf-4926-806e-79a1fa579185	ID	\N	\N	Indonesien	2020-10-29 13:33:17.227652	\N	\N	\N	\N	2020-10-29 13:33:17.229466	2020-10-29 13:33:17.229466	\N	\N
37014aa9-21db-4637-82f5-a5d3adb71fb5	IQ	\N	\N	Irak	2020-10-29 13:33:17.260583	\N	\N	\N	\N	2020-10-29 13:33:17.261196	2020-10-29 13:33:17.261196	\N	\N
9e550a65-98ca-45e6-aad1-cb2bfe2c9d0b	IR	\N	\N	Iran, Islamische Republik	2020-10-29 13:33:17.278649	\N	\N	\N	\N	2020-10-29 13:33:17.279165	2020-10-29 13:33:17.279165	\N	\N
7236a3ad-6155-4bda-9673-272de8f48a49	IE	\N	\N	Irland	2020-10-29 13:33:17.295115	\N	\N	\N	\N	2020-10-29 13:33:17.295558	2020-10-29 13:33:17.295558	\N	\N
575e0f76-69e4-472e-b699-05db6f8a99c7	IS	\N	\N	Island	2020-10-29 13:33:17.339601	\N	\N	\N	\N	2020-10-29 13:33:17.341411	2020-10-29 13:33:17.341411	\N	\N
2d5199ab-d7cb-4cdb-80f7-3d48eed63d58	IM	\N	\N	Isle of Man	2020-10-29 13:33:17.380746	\N	\N	\N	\N	2020-10-29 13:33:17.381335	2020-10-29 13:33:17.381335	\N	\N
7712e4f5-0c77-4594-9996-38d283f77fc5	IL	\N	\N	Israel	2020-10-29 13:33:17.398547	\N	\N	\N	\N	2020-10-29 13:33:17.398946	2020-10-29 13:33:17.398946	\N	\N
7ea89469-b582-4abe-8859-ce62af920071	IT	\N	\N	Italien	2020-10-29 13:33:17.422598	\N	\N	\N	\N	2020-10-29 13:33:17.423202	2020-10-29 13:33:17.423202	\N	\N
cedfa717-88c9-4adf-ad3f-5b44a6a58517	JM	\N	\N	Jamaika	2020-10-29 13:33:17.451076	\N	\N	\N	\N	2020-10-29 13:33:17.451676	2020-10-29 13:33:17.451676	\N	\N
305a5648-bf49-48da-8ada-c65bde17bf37	JP	\N	\N	Japan	2020-10-29 13:33:17.470563	\N	\N	\N	\N	2020-10-29 13:33:17.471189	2020-10-29 13:33:17.471189	\N	\N
4c3c57f3-643a-42ce-b482-01e4ee3ab4ee	YE	\N	\N	Jemen	2020-10-29 13:33:17.490463	\N	\N	\N	\N	2020-10-29 13:33:17.491061	2020-10-29 13:33:17.491061	\N	\N
120f69a4-0d69-409b-8598-816426be9767	JE	\N	\N	Jersey	2020-10-29 13:33:17.509913	\N	\N	\N	\N	2020-10-29 13:33:17.510423	2020-10-29 13:33:17.510423	\N	\N
bee9ba94-8a07-4046-a60c-65d9487337c9	JO	\N	\N	Jordanien	2020-10-29 13:33:17.529588	\N	\N	\N	\N	2020-10-29 13:33:17.530231	2020-10-29 13:33:17.530231	\N	\N
368da47a-9db8-47cd-9519-565489e7cb8b	KY	\N	\N	Kaimaninseln	2020-10-29 13:33:17.550084	\N	\N	\N	\N	2020-10-29 13:33:17.550708	2020-10-29 13:33:17.550708	\N	\N
8b1842fb-4988-4b41-98c0-a3638285519c	KH	\N	\N	Kambodscha	2020-10-29 13:33:17.569991	\N	\N	\N	\N	2020-10-29 13:33:17.570588	2020-10-29 13:33:17.570588	\N	\N
f5dbf128-de9c-4c63-8be2-3143d271fdbe	CM	\N	\N	Kamerun	2020-10-29 13:33:17.589665	\N	\N	\N	\N	2020-10-29 13:33:17.590262	2020-10-29 13:33:17.590262	\N	\N
c66f6c7a-0d11-41dc-867a-9a4cc974ba48	CA	\N	\N	Kanada	2020-10-29 13:33:17.609262	\N	\N	\N	\N	2020-10-29 13:33:17.60986	2020-10-29 13:33:17.60986	\N	\N
4460ed72-0136-4743-b53a-77d10c41e84a	CV	\N	\N	Kap Verde	2020-10-29 13:33:17.653441	\N	\N	\N	\N	2020-10-29 13:33:17.655116	2020-10-29 13:33:17.655116	\N	\N
b6f893cc-3136-421b-9475-e6d199fd5c97	KZ	\N	\N	Kasachstan	2020-10-29 13:33:17.685776	\N	\N	\N	\N	2020-10-29 13:33:17.686394	2020-10-29 13:33:17.686394	\N	\N
cabef119-e7c6-4a75-8a8d-eee555796b80	QA	\N	\N	Katar (Qatari)	2020-10-29 13:33:17.704115	\N	\N	\N	\N	2020-10-29 13:33:17.704662	2020-10-29 13:33:17.704662	\N	\N
abda1a65-f18d-4c76-94bc-869793906985	KE	\N	\N	Kenia	2020-10-29 13:33:17.722579	\N	\N	\N	\N	2020-10-29 13:33:17.723139	2020-10-29 13:33:17.723139	\N	\N
0ed6b36f-0784-463f-b9a3-f2373328b135	KG	\N	\N	Kirgisistan	2020-10-29 13:33:17.742351	\N	\N	\N	\N	2020-10-29 13:33:17.743014	2020-10-29 13:33:17.743014	\N	\N
eb09c086-c8fe-47f9-83b8-b4bf655a4aa7	KI	\N	\N	Kiribati, Republik	2020-10-29 13:33:17.760562	\N	\N	\N	\N	2020-10-29 13:33:17.761106	2020-10-29 13:33:17.761106	\N	\N
055d4bb3-0008-42c4-95cf-26d40f9f7dc5	CC	\N	\N	Kokosinseln	2020-10-29 13:33:17.778777	\N	\N	\N	\N	2020-10-29 13:33:17.779334	2020-10-29 13:33:17.779334	\N	\N
1e2baea2-605b-4813-9295-6ff522bb14f5	CO	\N	\N	Kolumbien	2020-10-29 13:33:17.797557	\N	\N	\N	\N	2020-10-29 13:33:17.798056	2020-10-29 13:33:17.798056	\N	\N
360549b9-d28b-4ed4-9cae-766e6de27397	KM	\N	\N	Komoren, Islamische Bundesrepublik	2020-10-29 13:33:17.815697	\N	\N	\N	\N	2020-10-29 13:33:17.816274	2020-10-29 13:33:17.816274	\N	\N
353d6829-61e1-4081-8055-921757314ab1	CD	\N	\N	Kongo, Demokratische Republik (ehem Zaire)	2020-10-29 13:33:17.833669	\N	\N	\N	\N	2020-10-29 13:33:17.834152	2020-10-29 13:33:17.834152	\N	\N
649513cf-ca0a-4b95-8896-6b92b2ef5d04	ZR	\N	\N	Kongo, Demokratische Republik (ex-Zaire)	2020-10-29 13:33:17.853908	\N	\N	\N	\N	2020-10-29 13:33:17.854469	2020-10-29 13:33:17.854469	\N	\N
a0ba054a-1473-436b-8747-d005e63c2033	CG	\N	\N	Kongo, Republik	2020-10-29 13:33:17.874429	\N	\N	\N	\N	2020-10-29 13:33:17.875087	2020-10-29 13:33:17.875087	\N	\N
8e173185-6f2b-4d25-ab29-79c039bee9fa	KP	\N	\N	Korea, Demokratische Volksrepublik	2020-10-29 13:33:17.895803	\N	\N	\N	\N	2020-10-29 13:33:17.896476	2020-10-29 13:33:17.896476	\N	\N
9307dbb9-5620-4682-b7a9-379c4640526e	KR	\N	\N	Korea, Republik	2020-10-29 13:33:17.919496	\N	\N	\N	\N	2020-10-29 13:33:17.920112	2020-10-29 13:33:17.920112	\N	\N
84686bbb-c984-4790-9225-5ee9b7250841	RK	\N	\N	Kosovo	2020-10-29 13:33:17.941258	\N	\N	\N	\N	2020-10-29 13:33:17.941903	2020-10-29 13:33:17.941903	\N	\N
47650299-7a33-407e-abb5-b75ad0325707	HR	\N	\N	Kroatien	2020-10-29 13:33:17.967072	\N	\N	\N	\N	2020-10-29 13:33:17.967722	2020-10-29 13:33:17.967722	\N	\N
d09e416d-77dc-4622-b695-8762682715b5	CU	\N	\N	Kuba	2020-10-29 13:33:17.988516	\N	\N	\N	\N	2020-10-29 13:33:17.989179	2020-10-29 13:33:17.989179	\N	\N
1eab005f-191d-4580-b2f3-7200f66c1f39	KW	\N	\N	Kuwait	2020-10-29 13:33:18.01334	\N	\N	\N	\N	2020-10-29 13:33:18.013839	2020-10-29 13:33:18.013839	\N	\N
b71551ef-34d2-43a1-8646-cf8a2fd01ac8	LA	\N	\N	Laos, Demokratische Volksrepublik	2020-10-29 13:33:18.029587	\N	\N	\N	\N	2020-10-29 13:33:18.030074	2020-10-29 13:33:18.030074	\N	\N
8c222885-c9cd-4c2a-9a41-be7dd200a7aa	LS	\N	\N	Lesotho, Königreich	2020-10-29 13:33:18.062745	\N	\N	\N	\N	2020-10-29 13:33:18.064723	2020-10-29 13:33:18.064723	\N	\N
01b54d28-9085-4b72-a079-c2bc4546919b	LV	\N	\N	Lettland	2020-10-29 13:33:18.089646	\N	\N	\N	\N	2020-10-29 13:33:18.090243	2020-10-29 13:33:18.090243	\N	\N
531836f8-a19f-49dc-9ba4-2bc89edeb058	LB	\N	\N	Libanon	2020-10-29 13:33:18.114565	\N	\N	\N	\N	2020-10-29 13:33:18.116345	2020-10-29 13:33:18.116345	\N	\N
ad5e3c39-9f7d-4f34-9d42-9f555bb5c0e7	LR	\N	\N	Liberia	2020-10-29 13:33:18.167887	\N	\N	\N	\N	2020-10-29 13:33:18.16909	2020-10-29 13:33:18.16909	\N	\N
fe91233c-362b-4518-bd71-3a2612ebcdac	LY	\N	\N	Libysch-Arabische Volks-Jamahiria, Sozialistische	2020-10-29 13:33:18.192707	\N	\N	\N	\N	2020-10-29 13:33:18.193345	2020-10-29 13:33:18.193345	\N	\N
fedb267b-2ed6-46c6-89c2-1804f5776b0c	LI	\N	\N	Liechtenstein	2020-10-29 13:33:18.214166	\N	\N	\N	\N	2020-10-29 13:33:18.214853	2020-10-29 13:33:18.214853	\N	\N
6ac2b47b-8290-4bf8-b4b0-95b7f308035f	LT	\N	\N	Litauen	2020-10-29 13:33:18.235683	\N	\N	\N	\N	2020-10-29 13:33:18.236277	2020-10-29 13:33:18.236277	\N	\N
a5ecdd95-040f-437c-8867-06001bb81275	LU	\N	\N	Luxemburg	2020-10-29 13:33:18.255922	\N	\N	\N	\N	2020-10-29 13:33:18.256474	2020-10-29 13:33:18.256474	\N	\N
6fc79cc8-498d-4f41-980c-bb895c0e2bc1	MO	\N	\N	Macau (Aomen)	2020-10-29 13:33:18.273762	\N	\N	\N	\N	2020-10-29 13:33:18.274177	2020-10-29 13:33:18.274177	\N	\N
9e1a79df-491f-44bc-976a-8a47381c2155	MG	\N	\N	Madagaskar	2020-10-29 13:33:18.290667	\N	\N	\N	\N	2020-10-29 13:33:18.291042	2020-10-29 13:33:18.291042	\N	\N
8309308f-0f6e-4fe4-a19d-4304f5b26360	MW	\N	\N	Malawi	2020-10-29 13:33:18.305244	\N	\N	\N	\N	2020-10-29 13:33:18.305585	2020-10-29 13:33:18.305585	\N	\N
53ab2dc1-19be-462c-9f80-c039f1fe1e9a	MY	\N	\N	Malaysia	2020-10-29 13:33:18.319173	\N	\N	\N	\N	2020-10-29 13:33:18.31953	2020-10-29 13:33:18.31953	\N	\N
1c8f156a-0dba-466f-ae53-49cfeac77e4c	MV	\N	\N	Malediven	2020-10-29 13:33:18.333881	\N	\N	\N	\N	2020-10-29 13:33:18.334249	2020-10-29 13:33:18.334249	\N	\N
ff55c46e-b6c9-4afc-836f-e9c838f06e0e	ML	\N	\N	Mali	2020-10-29 13:33:18.350296	\N	\N	\N	\N	2020-10-29 13:33:18.350769	2020-10-29 13:33:18.350769	\N	\N
c1f920b5-ff65-44fa-a9f8-4df21f8cad64	MT	\N	\N	Malta	2020-10-29 13:33:18.382211	\N	\N	\N	\N	2020-10-29 13:33:18.382872	2020-10-29 13:33:18.382872	\N	\N
47d516d2-034f-4b2c-8f1f-12d64d8949a1	MA	\N	\N	Marokko	2020-10-29 13:33:18.401736	\N	\N	\N	\N	2020-10-29 13:33:18.402203	2020-10-29 13:33:18.402203	\N	\N
c334e188-a022-4317-81d7-e8081934f099	MH	\N	\N	Marshallinseln, Republik der	2020-10-29 13:33:18.418541	\N	\N	\N	\N	2020-10-29 13:33:18.41898	2020-10-29 13:33:18.41898	\N	\N
e17a7cb2-2827-4cd3-89f9-e5dc082ca8d7	MQ	\N	\N	Martinique	2020-10-29 13:33:18.433866	\N	\N	\N	\N	2020-10-29 13:33:18.43423	2020-10-29 13:33:18.43423	\N	\N
39c88479-be41-477d-8357-a3c1482817fa	MR	\N	\N	Mauretanien	2020-10-29 13:33:18.449853	\N	\N	\N	\N	2020-10-29 13:33:18.450311	2020-10-29 13:33:18.450311	\N	\N
24486882-8d87-4ec7-a731-e2cb42bc3b43	MU	\N	\N	Mauritius	2020-10-29 13:33:18.465985	\N	\N	\N	\N	2020-10-29 13:33:18.466335	2020-10-29 13:33:18.466335	\N	\N
c410a25d-f7de-437e-b29e-f24804288f00	YT	\N	\N	Mayotte	2020-10-29 13:33:18.493241	\N	\N	\N	\N	2020-10-29 13:33:18.494354	2020-10-29 13:33:18.494354	\N	\N
3bb941e9-984e-4c31-bc14-db4fdb3ff1da	MK	\N	\N	Mazedonien (ehem jugoslawische Republik)	2020-10-29 13:33:18.516919	\N	\N	\N	\N	2020-10-29 13:33:18.517509	2020-10-29 13:33:18.517509	\N	\N
c9f5e046-7c4b-4105-adf6-33eabaea08d7	MX	\N	\N	Mexiko	2020-10-29 13:33:18.536228	\N	\N	\N	\N	2020-10-29 13:33:18.536767	2020-10-29 13:33:18.536767	\N	\N
061295df-a106-4667-ac63-06b04b751558	FM	\N	\N	Mikronesien, Föderierte Staaten von	2020-10-29 13:33:18.553329	\N	\N	\N	\N	2020-10-29 13:33:18.553806	2020-10-29 13:33:18.553806	\N	\N
53fd02e6-2b9c-4a86-affa-78af86b24468	MC	\N	\N	Monaco	2020-10-29 13:33:18.571135	\N	\N	\N	\N	2020-10-29 13:33:18.57163	2020-10-29 13:33:18.57163	\N	\N
5383bc7e-73d0-4787-84c0-404171c5ab53	MN	\N	\N	Mongolei	2020-10-29 13:33:18.58882	\N	\N	\N	\N	2020-10-29 13:33:18.589347	2020-10-29 13:33:18.589347	\N	\N
68591a89-cd6e-48ba-a593-51148989e813	MS	\N	\N	Montserrat	2020-10-29 13:33:18.605894	\N	\N	\N	\N	2020-10-29 13:33:18.60628	2020-10-29 13:33:18.60628	\N	\N
5166332c-e246-40b4-a059-a5fb67720113	MZ	\N	\N	Mosambik	2020-10-29 13:33:18.633458	\N	\N	\N	\N	2020-10-29 13:33:18.633992	2020-10-29 13:33:18.633992	\N	\N
7cb5ad86-4a39-4060-a0d5-0ea00e724d90	MM	\N	\N	Myanmar (ehem Birma / Burma)	2020-10-29 13:33:18.666081	\N	\N	\N	\N	2020-10-29 13:33:18.667905	2020-10-29 13:33:18.667905	\N	\N
21ebfd87-2205-4dd4-ba72-60d282332e01	NA	\N	\N	Namibia	2020-10-29 13:33:18.714709	\N	\N	\N	\N	2020-10-29 13:33:18.715582	2020-10-29 13:33:18.715582	\N	\N
667926be-2ab3-47cf-b85a-0406cc8f374c	NR	\N	\N	Nauru	2020-10-29 13:33:18.738498	\N	\N	\N	\N	2020-10-29 13:33:18.739189	2020-10-29 13:33:18.739189	\N	\N
e3a409e9-b985-4a0d-a23c-67679b09bf05	NP	\N	\N	Nepal	2020-10-29 13:33:18.761247	\N	\N	\N	\N	2020-10-29 13:33:18.761946	2020-10-29 13:33:18.761946	\N	\N
c2f2f273-ace6-4484-838f-549a6a78bf92	NC	\N	\N	Neukaledonien	2020-10-29 13:33:18.784784	\N	\N	\N	\N	2020-10-29 13:33:18.785583	2020-10-29 13:33:18.785583	\N	\N
7618c153-ab69-4df5-913f-2cb6604fcc17	NZ	\N	\N	Neuseeland	2020-10-29 13:33:18.816711	\N	\N	\N	\N	2020-10-29 13:33:18.817468	2020-10-29 13:33:18.817468	\N	\N
572b4401-9ab3-4439-9f76-f59213251dfd	NI	\N	\N	Nicaragua	2020-10-29 13:33:18.841897	\N	\N	\N	\N	2020-10-29 13:33:18.842674	2020-10-29 13:33:18.842674	\N	\N
1cb79dcc-5840-4dfc-9f2f-85af9bd6653a	NL	\N	\N	Niederlande	2020-10-29 13:33:18.862145	\N	\N	\N	\N	2020-10-29 13:33:18.86259	2020-10-29 13:33:18.86259	\N	\N
45d34cda-9428-4eed-a351-1f0faba634f4	AN	\N	\N	Niederländische Antillen	2020-10-29 13:33:18.878145	\N	\N	\N	\N	2020-10-29 13:33:18.878489	2020-10-29 13:33:18.878489	\N	\N
9deca05b-4df7-45f6-89cf-489f8bb81a34	NE	\N	\N	Niger	2020-10-29 13:33:18.893276	\N	\N	\N	\N	2020-10-29 13:33:18.893621	2020-10-29 13:33:18.893621	\N	\N
a0c34275-4526-49b5-910d-605a197d64a0	NG	\N	\N	Nigeria	2020-10-29 13:33:18.907759	\N	\N	\N	\N	2020-10-29 13:33:18.908123	2020-10-29 13:33:18.908123	\N	\N
ab3a0d1d-9386-4492-9327-2c478d4635e3	NU	\N	\N	Niueinseln	2020-10-29 13:33:18.922318	\N	\N	\N	\N	2020-10-29 13:33:18.922661	2020-10-29 13:33:18.922661	\N	\N
075a5d1e-31ae-40c1-ad99-c022f70fb131	MP	\N	\N	Nördliche Marianen, Commenwealth der	2020-10-29 13:33:18.936847	\N	\N	\N	\N	2020-10-29 13:33:18.937183	2020-10-29 13:33:18.937183	\N	\N
5d13b868-4565-4226-917b-018068e3c3de	NF	\N	\N	Norfolkinseln	2020-10-29 13:33:18.951868	\N	\N	\N	\N	2020-10-29 13:33:18.952259	2020-10-29 13:33:18.952259	\N	\N
7be0cade-996d-491b-8168-9e50cdac6cb4	NO	\N	\N	Norwegen	2020-10-29 13:33:18.967032	\N	\N	\N	\N	2020-10-29 13:33:18.967394	2020-10-29 13:33:18.967394	\N	\N
e07e99e6-5724-4baa-b530-32ba9764dc6d	OM	\N	\N	Oman	2020-10-29 13:33:18.981701	\N	\N	\N	\N	2020-10-29 13:33:18.982067	2020-10-29 13:33:18.982067	\N	\N
95b1a118-f383-47e3-9294-2d35c61eec5f	AT	\N	\N	Österreich	2020-10-29 13:33:18.995564	\N	\N	\N	\N	2020-10-29 13:33:18.995899	2020-10-29 13:33:18.995899	\N	\N
02cdc5a5-e28b-4a68-8b8f-88c3deefbdb0	TP	\N	\N	Osttimor	2020-10-29 13:33:19.017366	\N	\N	\N	\N	2020-10-29 13:33:19.018149	2020-10-29 13:33:19.018149	\N	\N
a974447e-a401-4127-b319-10c2d8684669	PK	\N	\N	Pakistan	2020-10-29 13:33:19.038659	\N	\N	\N	\N	2020-10-29 13:33:19.039216	2020-10-29 13:33:19.039216	\N	\N
926176af-8c7f-41fc-a09a-b3fa85ec24be	PS	\N	\N	Palästina	2020-10-29 13:33:19.057373	\N	\N	\N	\N	2020-10-29 13:33:19.057957	2020-10-29 13:33:19.057957	\N	\N
9fd3672f-8435-4a0f-89a1-34f8a595662f	PW	\N	\N	Palau, Republik	2020-10-29 13:33:19.07536	\N	\N	\N	\N	2020-10-29 13:33:19.075903	2020-10-29 13:33:19.075903	\N	\N
e57b6698-6d4b-4c84-a865-02d02793ce15	PA	\N	\N	Panama	2020-10-29 13:33:19.093464	\N	\N	\N	\N	2020-10-29 13:33:19.093948	2020-10-29 13:33:19.093948	\N	\N
70830b4c-9f5b-43b6-bba5-3ea2fdf534eb	PG	\N	\N	Papua-Neuguinea	2020-10-29 13:33:19.111874	\N	\N	\N	\N	2020-10-29 13:33:19.112353	2020-10-29 13:33:19.112353	\N	\N
bc33ebca-67af-42cf-b555-47a03fa5f83d	PY	\N	\N	Paraguay	2020-10-29 13:33:19.131039	\N	\N	\N	\N	2020-10-29 13:33:19.131586	2020-10-29 13:33:19.131586	\N	\N
0ec74da7-7ef3-4f0d-830a-2af7ae81f1bc	PE	\N	\N	Peru	2020-10-29 13:33:19.149	\N	\N	\N	\N	2020-10-29 13:33:19.149423	2020-10-29 13:33:19.149423	\N	\N
1d028def-dd4f-46f7-be83-9c24d75b3ce6	PH	\N	\N	Philippinen	2020-10-29 13:33:19.164618	\N	\N	\N	\N	2020-10-29 13:33:19.165097	2020-10-29 13:33:19.165097	\N	\N
d34c6e5c-9c59-4592-8f55-a96a37e5a20c	PN	\N	\N	Pitcairninseln	2020-10-29 13:33:19.180062	\N	\N	\N	\N	2020-10-29 13:33:19.180524	2020-10-29 13:33:19.180524	\N	\N
fcd2d456-977a-475e-b659-b06bb5155b08	PL	\N	\N	Polen	2020-10-29 13:33:19.196401	\N	\N	\N	\N	2020-10-29 13:33:19.196858	2020-10-29 13:33:19.196858	\N	\N
b4078b48-c035-4d13-968b-ee16dac20c05	PT	\N	\N	Portugal	2020-10-29 13:33:19.212587	\N	\N	\N	\N	2020-10-29 13:33:19.213058	2020-10-29 13:33:19.213058	\N	\N
1e892a45-a9be-42c3-b02d-330f04219fc0	PR	\N	\N	Puerto Rico	2020-10-29 13:33:19.228883	\N	\N	\N	\N	2020-10-29 13:33:19.229242	2020-10-29 13:33:19.229242	\N	\N
6686ac5a-a130-4d2b-a188-3df64af56d80	MD	\N	\N	Republik, Moldau	2020-10-29 13:33:19.243399	\N	\N	\N	\N	2020-10-29 13:33:19.243743	2020-10-29 13:33:19.243743	\N	\N
51f9aebc-33a5-435f-92a4-0d02f48c2bbd	ME	\N	\N	Republik Montenegro	2020-10-29 13:33:19.260623	\N	\N	\N	\N	2020-10-29 13:33:19.260971	2020-10-29 13:33:19.260971	\N	\N
54cc9d01-4bbf-4e14-9490-3aa60ee6e509	RS	\N	\N	Republik Serbien	2020-10-29 13:33:19.275585	\N	\N	\N	\N	2020-10-29 13:33:19.275947	2020-10-29 13:33:19.275947	\N	\N
46282f40-8d56-49ce-a390-a27ef409d5a5	RW	\N	\N	Ruanda	2020-10-29 13:33:19.290479	\N	\N	\N	\N	2020-10-29 13:33:19.290839	2020-10-29 13:33:19.290839	\N	\N
5eef1aa9-daa4-45b8-9c86-93ba94df95e9	RO	\N	\N	Rumänien	2020-10-29 13:33:19.305809	\N	\N	\N	\N	2020-10-29 13:33:19.306168	2020-10-29 13:33:19.306168	\N	\N
63c616ec-1e12-41ce-9e91-b1ed9e76be0b	RU	\N	\N	Russische Föderation	2020-10-29 13:33:19.331011	\N	\N	\N	\N	2020-10-29 13:33:19.332828	2020-10-29 13:33:19.332828	\N	\N
34951266-6632-4c30-9d8b-ea2cfbca7912	SB	\N	\N	Salomonen	2020-10-29 13:33:19.375563	\N	\N	\N	\N	2020-10-29 13:33:19.376493	2020-10-29 13:33:19.376493	\N	\N
46a34d38-caa7-4482-937e-f6f6a466b213	ZM	\N	\N	Sambia	2020-10-29 13:33:19.411656	\N	\N	\N	\N	2020-10-29 13:33:19.412582	2020-10-29 13:33:19.412582	\N	\N
2736c425-87cb-4b66-b21f-079696340d7a	WS	\N	\N	Samoa (Westsamoa)	2020-10-29 13:33:19.441863	\N	\N	\N	\N	2020-10-29 13:33:19.442868	2020-10-29 13:33:19.442868	\N	\N
214ac0da-8dd5-4b89-81e5-ca8d957de6c3	ST	\N	\N	São Tomé und Principe, Demokratische Republik	2020-10-29 13:33:19.482168	\N	\N	\N	\N	2020-10-29 13:33:19.482981	2020-10-29 13:33:19.482981	\N	\N
a377be26-67c3-425f-abcf-5f06acf383f9	SA	\N	\N	Saudi Arabien	2020-10-29 13:33:19.513485	\N	\N	\N	\N	2020-10-29 13:33:19.514264	2020-10-29 13:33:19.514264	\N	\N
150c0008-6477-4d2c-9da5-dd988d29222b	SE	\N	\N	Schweden	2020-10-29 13:33:19.538934	\N	\N	\N	\N	2020-10-29 13:33:19.539695	2020-10-29 13:33:19.539695	\N	\N
cbb86237-aae3-46e9-8a14-75fcfacd513f	CH	\N	\N	Schweiz	2020-10-29 13:33:19.56657	\N	\N	\N	\N	2020-10-29 13:33:19.567374	2020-10-29 13:33:19.567374	\N	\N
ced5bc1c-a708-4d8e-bca5-cba75db747af	SN	\N	\N	Senegal	2020-10-29 13:33:19.591728	\N	\N	\N	\N	2020-10-29 13:33:19.592582	2020-10-29 13:33:19.592582	\N	\N
d4a1e37e-285e-4804-af95-c5263ed8ea16	SC	\N	\N	Seychellen	2020-10-29 13:33:19.617668	\N	\N	\N	\N	2020-10-29 13:33:19.618436	2020-10-29 13:33:19.618436	\N	\N
73b35aff-05c1-4f6d-8a10-be823fbb598c	SL	\N	\N	Sierra Leone	2020-10-29 13:33:19.643287	\N	\N	\N	\N	2020-10-29 13:33:19.644083	2020-10-29 13:33:19.644083	\N	\N
7d5169ee-dd91-49a2-905e-5f64b8c639d3	ZW	\N	\N	Simbabwe	2020-10-29 13:33:19.668567	\N	\N	\N	\N	2020-10-29 13:33:19.669358	2020-10-29 13:33:19.669358	\N	\N
e9e726ca-0c17-4ef2-8af1-982792634943	SG	\N	\N	Singapur	2020-10-29 13:33:19.693963	\N	\N	\N	\N	2020-10-29 13:33:19.694688	2020-10-29 13:33:19.694688	\N	\N
4f0a1a66-74d6-425f-bb84-48e04bdc9f9c	SK	\N	\N	Slowakische Republik	2020-10-29 13:33:19.719009	\N	\N	\N	\N	2020-10-29 13:33:19.719779	2020-10-29 13:33:19.719779	\N	\N
f743b0a0-71a5-45bd-8545-0903002c9265	SI	\N	\N	Slowenien	2020-10-29 13:33:19.744403	\N	\N	\N	\N	2020-10-29 13:33:19.745142	2020-10-29 13:33:19.745142	\N	\N
15182225-985a-426b-8d2c-5a3ab2626359	SO	\N	\N	Somalia	2020-10-29 13:33:19.768941	\N	\N	\N	\N	2020-10-29 13:33:19.769704	2020-10-29 13:33:19.769704	\N	\N
de8bc16b-ac92-47b1-bdd5-1b91cd7bc462	ES	\N	\N	Spanien	2020-10-29 13:33:19.790984	\N	\N	\N	\N	2020-10-29 13:33:19.791512	2020-10-29 13:33:19.791512	\N	\N
a2b9ee00-9396-47b0-90a0-7fa7e3cf4ae6	LK	\N	\N	Sri Lanka (ehem Ceylon)	2020-10-29 13:33:19.807566	\N	\N	\N	\N	2020-10-29 13:33:19.808046	2020-10-29 13:33:19.808046	\N	\N
3b293c46-4542-47cd-9bdf-8ada8db0fcc1	SH	\N	\N	St. Helena	2020-10-29 13:33:19.835263	\N	\N	\N	\N	2020-10-29 13:33:19.835781	2020-10-29 13:33:19.835781	\N	\N
ffc39fe5-3bd4-43ff-b501-c0db3c6f85e2	KN	\N	\N	St. Kitts und Nevis (ehem St. Christopher und Nevis)	2020-10-29 13:33:19.860624	\N	\N	\N	\N	2020-10-29 13:33:19.861374	2020-10-29 13:33:19.861374	\N	\N
871237e5-4e0c-4e43-b4a8-7b89584f8dac	LC	\N	\N	St. Lucia	2020-10-29 13:33:19.88685	\N	\N	\N	\N	2020-10-29 13:33:19.887636	2020-10-29 13:33:19.887636	\N	\N
9eb8131c-7a9e-49e0-97bb-939e34ad5837	SM	\N	\N	St. Marino	2020-10-29 13:33:19.912709	\N	\N	\N	\N	2020-10-29 13:33:19.913509	2020-10-29 13:33:19.913509	\N	\N
8959db00-c752-410a-8125-6adfd3ae2a41	PM	\N	\N	St. Pierre und Miquelon	2020-10-29 13:33:19.939269	\N	\N	\N	\N	2020-10-29 13:33:19.940025	2020-10-29 13:33:19.940025	\N	\N
4734d4c7-35db-4844-aa87-ee342ea751bf	VC	\N	\N	St. Vincent und die Grenadinen	2020-10-29 13:33:19.964578	\N	\N	\N	\N	2020-10-29 13:33:19.965294	2020-10-29 13:33:19.965294	\N	\N
398b14f0-70b1-4277-989e-1f147a460caf	ZA	\N	\N	Südafrika	2020-10-29 13:33:19.990408	\N	\N	\N	\N	2020-10-29 13:33:19.991093	2020-10-29 13:33:19.991093	\N	\N
91d59e93-0219-4dc4-83c9-1270538b1823	SD	\N	\N	Sudan, Republik	2020-10-29 13:33:20.026418	\N	\N	\N	\N	2020-10-29 13:33:20.028406	2020-10-29 13:33:20.028406	\N	\N
7832f506-50e0-4ab9-9208-82fd958c0ac8	GS	\N	\N	Südgeorgien und die Sandwichinseln	2020-10-29 13:33:20.085592	\N	\N	\N	\N	2020-10-29 13:33:20.087219	2020-10-29 13:33:20.087219	\N	\N
ccacc3d5-c4d5-4626-9b4e-85a1799a3f67	SR	\N	\N	Suriname	2020-10-29 13:33:20.112759	\N	\N	\N	\N	2020-10-29 13:33:20.113373	2020-10-29 13:33:20.113373	\N	\N
1f4383c7-3005-4fa8-bb2e-cfddf15dc9ed	SZ	\N	\N	Swasiland	2020-10-29 13:33:20.133553	\N	\N	\N	\N	2020-10-29 13:33:20.134198	2020-10-29 13:33:20.134198	\N	\N
13a390f1-93f4-4e79-b18c-d64175a8698e	SY	\N	\N	Syrien, Arabische Republik	2020-10-29 13:33:20.15438	\N	\N	\N	\N	2020-10-29 13:33:20.154989	2020-10-29 13:33:20.154989	\N	\N
a9857a91-a49c-4653-ae14-d9d5fef9ce80	TJ	\N	\N	Tadschikistan	2020-10-29 13:33:20.174944	\N	\N	\N	\N	2020-10-29 13:33:20.175598	2020-10-29 13:33:20.175598	\N	\N
1113303b-6624-4a42-95e8-0eb907fc4ed5	TZ	\N	\N	Tansania	2020-10-29 13:33:20.194833	\N	\N	\N	\N	2020-10-29 13:33:20.195373	2020-10-29 13:33:20.195373	\N	\N
5c417336-23ae-47b8-81a8-ead6e44100fc	TH	\N	\N	Thailand	2020-10-29 13:33:20.21545	\N	\N	\N	\N	2020-10-29 13:33:20.215989	2020-10-29 13:33:20.215989	\N	\N
c5d0b96e-fbe8-4074-b0e5-a38f9ae7e0eb	TG	\N	\N	Togo	2020-10-29 13:33:20.233884	\N	\N	\N	\N	2020-10-29 13:33:20.234393	2020-10-29 13:33:20.234393	\N	\N
685c45f7-0bab-48a6-8452-d0db3799960c	TK	\N	\N	Tokelau	2020-10-29 13:33:20.250653	\N	\N	\N	\N	2020-10-29 13:33:20.251027	2020-10-29 13:33:20.251027	\N	\N
8fc3f06a-afca-4aff-9970-3b23de9e538d	TO	\N	\N	Tonga, Königreich	2020-10-29 13:33:20.265296	\N	\N	\N	\N	2020-10-29 13:33:20.26567	2020-10-29 13:33:20.26567	\N	\N
297dc1df-6441-4857-a8b7-b617207d49a6	TT	\N	\N	Trinidad und Tobago	2020-10-29 13:33:20.280182	\N	\N	\N	\N	2020-10-29 13:33:20.280575	2020-10-29 13:33:20.280575	\N	\N
eb846b07-a15c-453a-a2c6-f6054acebb77	TD	\N	\N	Tschad	2020-10-29 13:33:20.294747	\N	\N	\N	\N	2020-10-29 13:33:20.295098	2020-10-29 13:33:20.295098	\N	\N
bf2345ee-2d5d-4303-98bb-f00ce00c6b91	CZ	\N	\N	Tschechische Republik	2020-10-29 13:33:20.310059	\N	\N	\N	\N	2020-10-29 13:33:20.310419	2020-10-29 13:33:20.310419	\N	\N
acd41b35-1641-45cf-ba6f-0eb9552adf08	TN	\N	\N	Tunesien	2020-10-29 13:33:20.326146	\N	\N	\N	\N	2020-10-29 13:33:20.32662	2020-10-29 13:33:20.32662	\N	\N
b3ff8822-62c4-477b-a57d-ec1a6ea8de6f	TR	\N	\N	Türkei	2020-10-29 13:33:20.342801	\N	\N	\N	\N	2020-10-29 13:33:20.346245	2020-10-29 13:33:20.346245	\N	\N
85d7e406-c214-400a-8cd8-ed23d54be974	TM	\N	\N	Turkmenistan	2020-10-29 13:33:20.365333	\N	\N	\N	\N	2020-10-29 13:33:20.365799	2020-10-29 13:33:20.365799	\N	\N
26673026-2ee9-43c5-aa3c-a127c11f0a3a	TC	\N	\N	Turks- und Caicosinseln	2020-10-29 13:33:20.381568	\N	\N	\N	\N	2020-10-29 13:33:20.382024	2020-10-29 13:33:20.382024	\N	\N
10156a6c-38d3-469b-8991-3de7c33c0ec1	TV	\N	\N	Tuvalu	2020-10-29 13:33:20.400185	\N	\N	\N	\N	2020-10-29 13:33:20.40064	2020-10-29 13:33:20.40064	\N	\N
da2cc00b-7a38-41e8-84e6-9cb2675414e2	UG	\N	\N	Uganda	2020-10-29 13:33:20.443301	\N	\N	\N	\N	2020-10-29 13:33:20.444482	2020-10-29 13:33:20.444482	\N	\N
0f99978d-25f5-49ab-b6db-9747d7c52ff1	UA	\N	\N	Ukraine	2020-10-29 13:33:20.476718	\N	\N	\N	\N	2020-10-29 13:33:20.478023	2020-10-29 13:33:20.478023	\N	\N
13a1edf5-ff4b-4907-b6ed-00b3ea54c5a6	HU	\N	\N	Ungarn	2020-10-29 13:33:20.515182	\N	\N	\N	\N	2020-10-29 13:33:20.51637	2020-10-29 13:33:20.51637	\N	\N
5d2cc928-573b-49de-af9e-9e1d2db71c64	UY	\N	\N	Uruguay	2020-10-29 13:33:20.54693	\N	\N	\N	\N	2020-10-29 13:33:20.547662	2020-10-29 13:33:20.547662	\N	\N
f36f5f14-b924-4d4f-928f-b0886e7efab7	UZ	\N	\N	Usbekistan	2020-10-29 13:33:20.58241	\N	\N	\N	\N	2020-10-29 13:33:20.583032	2020-10-29 13:33:20.583032	\N	\N
319d291b-9c7f-4b01-a7b6-f7ba84916a40	VU	\N	\N	Vanuatu	2020-10-29 13:33:20.605644	\N	\N	\N	\N	2020-10-29 13:33:20.606153	2020-10-29 13:33:20.606153	\N	\N
ee71765a-2959-444c-8fef-7ef492ffed45	VA	\N	\N	Vatikanstadt	2020-10-29 13:33:20.633371	\N	\N	\N	\N	2020-10-29 13:33:20.633739	2020-10-29 13:33:20.633739	\N	\N
3da67365-62f9-4774-a9f5-e7d44df49ac0	VE	\N	\N	Venezuela	2020-10-29 13:33:20.663472	\N	\N	\N	\N	2020-10-29 13:33:20.664041	2020-10-29 13:33:20.664041	\N	\N
2f2bb2d0-b5c5-4d44-9a2c-17c95b02ff2d	AE	\N	\N	Vereinigte Arabische Emirate	2020-10-29 13:33:20.687621	\N	\N	\N	\N	2020-10-29 13:33:20.688287	2020-10-29 13:33:20.688287	\N	\N
0107c66a-eeb6-445b-aef4-01a6de6654c2	US	\N	\N	Vereinigte Staaten von Amerika	2020-10-29 13:33:20.710159	\N	\N	\N	\N	2020-10-29 13:33:20.710553	2020-10-29 13:33:20.710553	\N	\N
b94a1a17-4a5f-4d56-8897-86dfb59339f6	GB	\N	\N	Vereinigtes Königreich Großbritannien	2020-10-29 13:33:20.724534	\N	\N	\N	\N	2020-10-29 13:33:20.724882	2020-10-29 13:33:20.724882	\N	\N
3214357e-28f5-4e4b-b9ad-ebc2d0fc3997	VN	\N	\N	Vietnam	2020-10-29 13:33:20.739287	\N	\N	\N	\N	2020-10-29 13:33:20.739613	2020-10-29 13:33:20.739613	\N	\N
7b200c93-8a4a-4930-975c-2be4393d2118	WF	\N	\N	Wallis und Futuna	2020-10-29 13:33:20.754763	\N	\N	\N	\N	2020-10-29 13:33:20.755243	2020-10-29 13:33:20.755243	\N	\N
419bb088-b9af-4e97-b41b-4e1f3b424126	CX	\N	\N	Weihnachtsinseln	2020-10-29 13:33:20.790821	\N	\N	\N	\N	2020-10-29 13:33:20.792682	2020-10-29 13:33:20.792682	\N	\N
d8a2bb86-01fd-486a-8a2c-96861bfa341d	BY	\N	\N	Weißrußland (Belarus)	2020-10-29 13:33:20.839584	\N	\N	\N	\N	2020-10-29 13:33:20.840499	2020-10-29 13:33:20.840499	\N	\N
128f0028-1988-4505-8629-4e104c23460e	CF	\N	\N	Zentralafrikanische Republik	2020-10-29 13:33:20.861035	\N	\N	\N	\N	2020-10-29 13:33:20.861541	2020-10-29 13:33:20.861541	\N	\N
614b7905-3569-4b88-aaa6-05d7a9668746	CY	\N	\N	Zypern	2020-10-29 13:33:20.879569	\N	\N	\N	\N	2020-10-29 13:33:20.880148	2020-10-29 13:33:20.880148	\N	\N
bd9fe0b3-043f-4f94-b17d-ae4a13fd9fbc	EUR	\N	\N	Euro	2020-10-29 13:33:20.902746	\N	\N	\N	\N	2020-10-29 13:33:20.903307	2020-10-29 13:33:20.903307	\N	\N
ac9132af-65e2-48b8-8efe-146feea6c3cc	USD	\N	\N	US-Dollar	2020-10-29 13:33:20.920953	\N	\N	\N	\N	2020-10-29 13:33:20.921504	2020-10-29 13:33:20.921504	\N	\N
d05c44d3-5715-4fd8-a712-d1b960748f08	HUF	\N	\N	Ungarische Forint	2020-10-29 13:33:20.945973	\N	\N	\N	\N	2020-10-29 13:33:20.947807	2020-10-29 13:33:20.947807	\N	\N
21919b7f-bd80-48cd-8ba8-46b8ea1057ee	CZK	\N	\N	Tschechische Kronen	2020-10-29 13:33:20.978346	\N	\N	\N	\N	2020-10-29 13:33:20.978942	2020-10-29 13:33:20.978942	\N	\N
f984dbd4-3ab0-412f-aa29-750239cc5e0d	HRK	\N	\N	Kroatische Kuna	2020-10-29 13:33:20.997032	\N	\N	\N	\N	2020-10-29 13:33:20.997603	2020-10-29 13:33:20.997603	\N	\N
494c94a4-5b42-4eca-9d66-c01257306ca8	CHF	\N	\N	Schweizer Franken	2020-10-29 13:33:21.016471	\N	\N	\N	\N	2020-10-29 13:33:21.016938	2020-10-29 13:33:21.016938	\N	\N
0bb527f1-1be8-4bbe-8f26-0a26b7ff9ca3	PLN	\N	\N	Polnische Złoty	2020-10-29 13:33:21.046294	\N	\N	\N	\N	2020-10-29 13:33:21.046869	2020-10-29 13:33:21.046869	\N	\N
80fcec7a-decb-4196-aa1a-a068e65eea9d	DKK	\N	\N	Dänische Kronen	2020-10-29 13:33:21.06796	\N	\N	\N	\N	2020-10-29 13:33:21.06858	2020-10-29 13:33:21.06858	\N	\N
467b5ceb-74e6-4740-9121-39a1a3dbb105	Open Data	\N	\N	\N	2020-10-29 13:33:21.093328	\N	\N	\N	\N	2020-10-29 13:33:21.09393	2020-10-29 13:33:21.09393	\N	\N
2a833812-65e4-48b5-94c4-292ad56fb75e	Creative Commons	\N	\N	\N	2020-10-29 13:33:21.113227	\N	\N	\N	\N	2020-10-29 13:33:21.113719	2020-10-29 13:33:21.113719	\N	\N
69257ce3-5416-4cb6-ba6d-9e5e19f326bb	Public Domain Mark	\N	\N	\N	2020-10-29 13:33:21.132858	\N	\N	\N	\N	2020-10-29 13:33:21.133444	2020-10-29 13:33:21.133444	\N	https://creativecommons.org/publicdomain/mark/1.0/
70565ca6-4b22-4707-96c1-539d13d31d3f	CC0	\N	\N	\N	2020-10-29 13:33:21.157285	\N	\N	\N	\N	2020-10-29 13:33:21.157721	2020-10-29 13:33:21.157721	\N	https://creativecommons.org/publicdomain/zero/1.0/
549fb0a2-83d7-4571-a701-b37a377a16e3	CC BY	\N	\N	\N	2020-10-29 13:33:21.173553	\N	\N	\N	\N	2020-10-29 13:33:21.173942	2020-10-29 13:33:21.173942	\N	\N
d08e37eb-3281-410c-a23b-e63e4520bff8	CC BY 4.0	\N	\N	\N	2020-10-29 13:33:21.189161	\N	\N	\N	\N	2020-10-29 13:33:21.18962	2020-10-29 13:33:21.18962	\N	https://creativecommons.org/licenses/by/4.0/
6564e10e-daf6-415e-ab30-ad8a212b1b58	CC BY-SA	\N	\N	\N	2020-10-29 13:33:21.209588	\N	\N	\N	\N	2020-10-29 13:33:21.210109	2020-10-29 13:33:21.210109	\N	\N
2e2f7299-cec4-4691-befc-e6c7370b68ff	CC BY-SA 4.0	\N	\N	\N	2020-10-29 13:33:21.226239	\N	\N	\N	\N	2020-10-29 13:33:21.226632	2020-10-29 13:33:21.226632	\N	https://creativecommons.org/licenses/by-sa/4.0/
3007c40a-4457-4e0c-8116-d6c1bc8a6875	CC BY-ND	\N	\N	\N	2020-10-29 13:33:21.242387	\N	\N	\N	\N	2020-10-29 13:33:21.242803	2020-10-29 13:33:21.242803	\N	\N
4ce2fc92-3b08-477c-b2e5-57efea3d5f46	CC BY-ND 4.0	\N	\N	\N	2020-10-29 13:33:21.2581	\N	\N	\N	\N	2020-10-29 13:33:21.258552	2020-10-29 13:33:21.258552	\N	https://creativecommons.org/licenses/by-nd/4.0/
0953cc7e-cbdb-42ad-9f97-31d8b33fe33d	CC BY-NC	\N	\N	\N	2020-10-29 13:33:21.273677	\N	\N	\N	\N	2020-10-29 13:33:21.274132	2020-10-29 13:33:21.274132	\N	\N
0179f5f8-2b1e-4959-b824-1e06271eb6e0	CC BY-NC 4.0	\N	\N	\N	2020-10-29 13:33:21.290143	\N	\N	\N	\N	2020-10-29 13:33:21.290535	2020-10-29 13:33:21.290535	\N	https://creativecommons.org/licenses/by-nc/4.0/
e200b786-3f61-46da-a0d2-b74bbcecd625	CC BY-NC-SA	\N	\N	\N	2020-10-29 13:33:21.306537	\N	\N	\N	\N	2020-10-29 13:33:21.306972	2020-10-29 13:33:21.306972	\N	\N
5e11d21d-b90c-4486-b75f-a5986d85f824	CC BY-NC-SA 4.0	\N	\N	\N	2020-10-29 13:33:21.322532	\N	\N	\N	\N	2020-10-29 13:33:21.322953	2020-10-29 13:33:21.322953	\N	https://creativecommons.org/licenses/by-nc-sa/4.0/
c98fe917-3f11-452d-a504-073a3221dbd5	CC BY-NC-ND	\N	\N	\N	2020-10-29 13:33:21.364333	\N	\N	\N	\N	2020-10-29 13:33:21.365081	2020-10-29 13:33:21.365081	\N	\N
dc2e6099-2ff2-49f3-a95a-18cdda7e7470	CC BY-NC-ND 4.0	\N	\N	\N	2020-10-29 13:33:21.384187	\N	\N	\N	\N	2020-10-29 13:33:21.384764	2020-10-29 13:33:21.384764	\N	https://creativecommons.org/licenses/by-nc-nd/4.0/
22b893a1-4cc4-49db-bca0-01619d3f85a8	Sonstiges	\N	\N	\N	2020-10-29 13:33:21.40974	\N	\N	\N	\N	2020-10-29 13:33:21.411578	2020-10-29 13:33:21.411578	\N	\N
882a3256-a965-4b38-8b4b-a2e55236e272	Teilnahme Online	\N	\N	\N	2020-10-29 13:33:21.44969	\N	\N	\N	\N	2020-10-29 13:33:21.45035	2020-10-29 13:33:21.45035	\N	https://pending.schema.org/OnlineEventAttendanceMode
ce45f0d2-9953-41b1-9c6e-0a2ee804637b	Teilnahme Offline	\N	\N	\N	2020-10-29 13:33:21.470841	\N	\N	\N	\N	2020-10-29 13:33:21.471458	2020-10-29 13:33:21.471458	\N	https://pending.schema.org/OfflineEventAttendanceMode
56c89a1b-5941-414b-a969-f7c96593aaca	Gemischte Teilnahme	\N	\N	\N	2020-10-29 13:33:21.491522	\N	\N	\N	\N	2020-10-29 13:33:21.492164	2020-10-29 13:33:21.492164	\N	https://pending.schema.org/MixedEventAttendanceMode
c05ea25d-3c6c-469d-9c96-3d2dc67d8efb	Veranstaltung abgesagt	\N	\N	\N	2020-10-29 13:33:21.515905	\N	\N	\N	\N	2020-10-29 13:33:21.516474	2020-10-29 13:33:21.516474	\N	https://schema.org/EventCancelled
42b864f1-333b-4b65-b0d9-13dbf80e66ef	zu Online-Veranstaltung umgewandelt	\N	\N	\N	2020-10-29 13:33:21.536108	\N	\N	\N	\N	2020-10-29 13:33:21.53672	2020-10-29 13:33:21.53672	\N	https://schema.org/EventMovedOnline
360a139d-b441-4324-803d-97c88168a53a	Veranstaltung auf unbekannten Zeitpunkt vertagt	\N	\N	\N	2020-10-29 13:33:21.556224	\N	\N	\N	\N	2020-10-29 13:33:21.556813	2020-10-29 13:33:21.556813	\N	https://schema.org/EventPostponed
60c93106-7e18-4442-b096-bc7050d76727	Veranstaltung verschoben	\N	\N	\N	2020-10-29 13:33:21.57646	\N	\N	\N	\N	2020-10-29 13:33:21.577099	2020-10-29 13:33:21.577099	\N	https://schema.org/EventRescheduled
53fd1dcf-584d-4559-81d6-e0cbdef2de11	Veranstaltung geplant	\N	\N	\N	2020-10-29 13:33:21.597343	\N	\N	\N	\N	2020-10-29 13:33:21.597952	2020-10-29 13:33:21.597952	\N	https://schema.org/EventScheduled
291503f2-c751-403b-8b97-69e65e0f371c	Download	\N	\N	\N	2020-10-29 13:33:21.622281	\N	\N	\N	\N	2020-10-29 13:33:21.6229	2020-10-29 13:33:21.6229	\N	https://schema.org/DownloadAction
20135e56-0cc9-40c8-8acf-2a9a06061230	externer Link	\N	\N	\N	2020-10-29 13:33:21.649652	\N	\N	\N	\N	2020-10-29 13:33:21.651445	2020-10-29 13:33:21.651445	\N	https://schema.org/ViewAction
d48be149-cfe3-449b-b661-0f9263e576b2	Bestellen	\N	\N	\N	2020-10-29 13:33:21.688103	\N	\N	\N	\N	2020-10-29 13:33:21.688834	2020-10-29 13:33:21.688834	\N	https://schema.org/OrderAction
e750a29f-8a92-4331-899e-cb27b948d888	Eingestellt	\N	\N	\N	2020-10-29 13:33:21.713752	\N	\N	\N	\N	2020-10-29 13:33:21.714401	2020-10-29 13:33:21.714401	\N	https://schema.org/Discontinued
1157270c-5129-4ca4-a488-1fa35fd490a8	Verfügbar	\N	\N	\N	2020-10-29 13:33:21.734803	\N	\N	\N	\N	2020-10-29 13:33:21.735436	2020-10-29 13:33:21.735436	\N	https://schema.org/InStock
96b9ac6d-5b56-4ffc-93e5-9a3ddadc2a35	Nur im Geschäft	\N	\N	\N	2020-10-29 13:33:21.75651	\N	\N	\N	\N	2020-10-29 13:33:21.757128	2020-10-29 13:33:21.757128	\N	https://schema.org/InStoreOnly
e05b396b-b5ea-40ac-b332-08b8194cdb28	Eingeschränkt verfügbar	\N	\N	\N	2020-10-29 13:33:21.798265	\N	\N	\N	\N	2020-10-29 13:33:21.799436	2020-10-29 13:33:21.799436	\N	https://schema.org/LimitedAvailability
f32814d9-06fe-413a-a919-bc3361c506d5	Nur online	\N	\N	\N	2020-10-29 13:33:21.836074	\N	\N	\N	\N	2020-10-29 13:33:21.837238	2020-10-29 13:33:21.837238	\N	https://schema.org/OnlineOnly
05856844-c16e-4e50-adee-7a36ffdc3d4d	Nicht vorrätig	\N	\N	\N	2020-10-29 13:33:21.868406	\N	\N	\N	\N	2020-10-29 13:33:21.869188	2020-10-29 13:33:21.869188	\N	https://schema.org/OutOfStock
b43f3a6e-b497-4f91-9953-b032ff516e6e	Vorbestellen	\N	\N	\N	2020-10-29 13:33:21.890702	\N	\N	\N	\N	2020-10-29 13:33:21.891407	2020-10-29 13:33:21.891407	\N	https://schema.org/PreOrder
ea1db596-7c5f-4321-ac8b-5915e20656fb	Vorverkauf	\N	\N	\N	2020-10-29 13:33:21.913257	\N	\N	\N	\N	2020-10-29 13:33:21.913956	2020-10-29 13:33:21.913956	\N	https://schema.org/PreSale
efb31859-766c-4a23-8c20-6e00f33148e0	Ausverkauft	\N	\N	\N	2020-10-29 13:33:21.935238	\N	\N	\N	\N	2020-10-29 13:33:21.935917	2020-10-29 13:33:21.935917	\N	https://schema.org/SoldOut
011c3ba7-fdd7-462d-a479-30d3f7b0071e	Gebäck	\N	\N	\N	2020-10-29 13:33:21.963258	\N	\N	\N	\N	2020-10-29 13:33:21.963924	2020-10-29 13:33:21.963924	\N	\N
690d1521-7b52-4500-883d-37a5c053bd67	Mehlspeise	\N	\N	\N	2020-10-29 13:33:21.98626	\N	\N	\N	\N	2020-10-29 13:33:21.986953	2020-10-29 13:33:21.986953	\N	\N
f3b438c5-e446-45de-b1da-01ea40649b12	asiatisch	\N	\N	\N	2020-10-29 13:33:22.009259	\N	\N	\N	\N	2020-10-29 13:33:22.009974	2020-10-29 13:33:22.009974	\N	\N
7a4eec2e-0d21-4a0e-935d-48d8456bc587	Vorspeise	\N	\N	\N	2020-10-29 13:33:22.040914	\N	\N	\N	\N	2020-10-29 13:33:22.041403	2020-10-29 13:33:22.041403	\N	\N
560a57f4-0453-4cea-b407-d75e65f74f22	freigegeben	\N	\N	\N	2020-10-29 13:33:22.073403	\N	\N	\N	\N	2020-10-29 13:33:22.074682	2020-10-29 13:33:22.074682	\N	\N
8857a7d7-0854-4e62-8d8c-f97c3cb5c00e	beim Partner	\N	\N	\N	2020-10-29 13:33:22.106597	\N	\N	\N	\N	2020-10-29 13:33:22.107288	2020-10-29 13:33:22.107288	\N	\N
dec13c23-66ab-4d90-b40c-2cef4defdb8b	in Review	\N	\N	\N	2020-10-29 13:33:22.128624	\N	\N	\N	\N	2020-10-29 13:33:22.129228	2020-10-29 13:33:22.129228	\N	\N
97541fca-0de2-432d-a812-275530b6f3f1	archiviert	\N	\N	\N	2020-10-29 13:33:22.14872	\N	\N	\N	\N	2020-10-29 13:33:22.149239	2020-10-29 13:33:22.149239	\N	\N
6e032409-884e-4fb0-bde1-997b855f86f2	nur Veranstaltungskalender	\N	\N	\N	2020-10-29 13:33:22.173091	\N	\N	\N	\N	2020-10-29 13:33:22.173738	2020-10-29 13:33:22.173738	\N	\N
767e1aba-99a4-4a9d-9fae-db0c9e5a2a2d	im Verkauf	\N	\N	\N	2020-10-29 13:33:22.193793	\N	\N	\N	\N	2020-10-29 13:33:22.194431	2020-10-29 13:33:22.194431	\N	\N
ee9531a3-1af4-4ea8-b955-e41a02fbfafe	online	\N	\N	\N	2020-10-29 13:33:22.214111	\N	\N	\N	\N	2020-10-29 13:33:22.214682	2020-10-29 13:33:22.214682	\N	\N
3ca7144a-e2a6-4381-bb78-579ab865d3e8	vorübergehend gestoppt	\N	\N	\N	2020-10-29 13:33:22.234646	\N	\N	\N	\N	2020-10-29 13:33:22.23526	2020-10-29 13:33:22.23526	\N	\N
45fa4f37-c77f-4110-be51-8504391df5c9	ausverkauft	\N	\N	\N	2020-10-29 13:33:22.255015	\N	\N	\N	\N	2020-10-29 13:33:22.255557	2020-10-29 13:33:22.255557	\N	\N
7bfc901c-7e35-4367-9a42-c7bf6c814bcd	Event wurde abgesagt	\N	\N	\N	2020-10-29 13:33:22.27518	\N	\N	\N	\N	2020-10-29 13:33:22.27575	2020-10-29 13:33:22.27575	\N	\N
34942033-50a8-4887-a671-69f0aadb9d27	Vorstellungsvariante vorhanden	\N	\N	\N	2020-10-29 13:33:22.300182	\N	\N	\N	\N	2020-10-29 13:33:22.300786	2020-10-29 13:33:22.300786	\N	\N
2fadc02e-913a-414b-a87f-263c2433c6f1	Preisübersteuerung/Preistabelle vorhanden	\N	\N	\N	2020-10-29 13:33:22.322838	\N	\N	\N	\N	2020-10-29 13:33:22.323433	2020-10-29 13:33:22.323433	\N	\N
cb318ab9-1bc6-4d02-9c1f-46b8b673d084	Frei für Wahlabo	\N	\N	\N	2020-10-29 13:33:22.342315	\N	\N	\N	\N	2020-10-29 13:33:22.342797	2020-10-29 13:33:22.342797	\N	\N
f6bab140-184b-49d7-a91a-bd0720799480	Personalisierung vorhanden	\N	\N	\N	2020-10-29 13:33:22.379913	\N	\N	\N	\N	2020-10-29 13:33:22.380609	2020-10-29 13:33:22.380609	\N	\N
74822108-e5a9-4f3e-a1a1-4c828297d010	Packetverwendung erforderlich	\N	\N	\N	2020-10-29 13:33:22.403509	\N	\N	\N	\N	2020-10-29 13:33:22.404236	2020-10-29 13:33:22.404236	\N	\N
165020e8-5dd5-454e-8c22-55ac4abacc72	Gehbehinderte	\N	\N	\N	2020-10-29 13:33:22.431156	\N	\N	\N	\N	2020-10-29 13:33:22.431769	2020-10-29 13:33:22.431769	\N	\N
09df4b91-b8a0-4a06-ad76-b0886849467a	barrierefrei	\N	\N	\N	2020-10-29 13:33:22.454294	\N	\N	\N	\N	2020-10-29 13:33:22.454989	2020-10-29 13:33:22.454989	\N	\N
a9a5dd7e-fc87-4602-8d33-af23a4ae1295	teilweise barrierefrei	\N	\N	\N	2020-10-29 13:33:22.477034	\N	\N	\N	\N	2020-10-29 13:33:22.477732	2020-10-29 13:33:22.477732	\N	\N
5ac8659e-7d6a-43c7-a3f4-b12589599b24	Rollstuhlfahrer	\N	\N	\N	2020-10-29 13:33:22.500164	\N	\N	\N	\N	2020-10-29 13:33:22.500869	2020-10-29 13:33:22.500869	\N	\N
e56f777b-5ae0-4d44-b32a-f7459616f04c	barrierefrei	\N	\N	\N	2020-10-29 13:33:22.523188	\N	\N	\N	\N	2020-10-29 13:33:22.52374	2020-10-29 13:33:22.52374	\N	\N
b86feea2-e44e-434b-9e30-9114c3ad10ee	teilweise barrierefrei	\N	\N	\N	2020-10-29 13:33:22.540827	\N	\N	\N	\N	2020-10-29 13:33:22.541313	2020-10-29 13:33:22.541313	\N	\N
55dcb700-5b95-49d3-b07d-1be71b432938	Hörbehinderte	\N	\N	\N	2020-10-29 13:33:22.561494	\N	\N	\N	\N	2020-10-29 13:33:22.562381	2020-10-29 13:33:22.562381	\N	\N
6ab38a22-0100-48d1-b28c-9a9bd1cce4cc	barrierefrei	\N	\N	\N	2020-10-29 13:33:22.583822	\N	\N	\N	\N	2020-10-29 13:33:22.584318	2020-10-29 13:33:22.584318	\N	\N
31103147-2d07-436b-9b0a-f77d75d399a7	teilweise barrierefrei	\N	\N	\N	2020-10-29 13:33:22.602797	\N	\N	\N	\N	2020-10-29 13:33:22.603302	2020-10-29 13:33:22.603302	\N	\N
e2c3f4e7-6c5f-4c18-b1f7-c5ca0cce89ba	Gehörlose	\N	\N	\N	2020-10-29 13:33:22.621077	\N	\N	\N	\N	2020-10-29 13:33:22.621639	2020-10-29 13:33:22.621639	\N	\N
a8ad2bd0-086f-4d97-b214-add8aa987214	barrierefrei	\N	\N	\N	2020-10-29 13:33:22.639833	\N	\N	\N	\N	2020-10-29 13:33:22.640375	2020-10-29 13:33:22.640375	\N	\N
a2bfa22a-fa60-44d5-939b-779b4adb7593	teilweise barrierefrei	\N	\N	\N	2020-10-29 13:33:22.658913	\N	\N	\N	\N	2020-10-29 13:33:22.659432	2020-10-29 13:33:22.659432	\N	\N
ab98a496-cea0-438f-a221-3fc61a1fb1f5	Sehbehinderte	\N	\N	\N	2020-10-29 13:33:22.695557	\N	\N	\N	\N	2020-10-29 13:33:22.696377	2020-10-29 13:33:22.696377	\N	\N
bc4e3b72-40b5-4293-ad84-dc118bc911e9	barrierefrei	\N	\N	\N	2020-10-29 13:33:22.726094	\N	\N	\N	\N	2020-10-29 13:33:22.726729	2020-10-29 13:33:22.726729	\N	\N
b133f604-5dbf-4532-85b1-adb404fb60da	teilweise barrierefrei	\N	\N	\N	2020-10-29 13:33:22.74636	\N	\N	\N	\N	2020-10-29 13:33:22.746941	2020-10-29 13:33:22.746941	\N	\N
2f46c09a-a1c4-43ec-9cca-fdd66b0a95d6	Blinde	\N	\N	\N	2020-10-29 13:33:22.767065	\N	\N	\N	\N	2020-10-29 13:33:22.767621	2020-10-29 13:33:22.767621	\N	\N
9b6f4421-4e3a-44de-bcaa-ec09f835ad09	barrierefrei	\N	\N	\N	2020-10-29 13:33:22.787306	\N	\N	\N	\N	2020-10-29 13:33:22.787869	2020-10-29 13:33:22.787869	\N	\N
d4672b38-f816-4071-9223-5511ec9e7531	teilweise barrierefrei	\N	\N	\N	2020-10-29 13:33:22.810457	\N	\N	\N	\N	2020-10-29 13:33:22.81115	2020-10-29 13:33:22.81115	\N	\N
c9c57b51-92b8-46c9-8f7a-7997f266a880	Kognitiv Beeinträchtigte	\N	\N	\N	2020-10-29 13:33:22.832089	\N	\N	\N	\N	2020-10-29 13:33:22.836359	2020-10-29 13:33:22.836359	\N	\N
a52afd23-3110-4fda-b102-1453bc6aaace	barrierefrei	\N	\N	\N	2020-10-29 13:33:22.855398	\N	\N	\N	\N	2020-10-29 13:33:22.855997	2020-10-29 13:33:22.855997	\N	\N
7608d317-8d4d-415f-9780-48c1073f17d6	teilweise barrierefrei	\N	\N	\N	2020-10-29 13:33:22.899385	\N	\N	\N	\N	2020-10-29 13:33:22.900219	2020-10-29 13:33:22.900219	\N	\N
022033c1-39c0-4c57-ac76-39a2995db7e8	Lift	\N	\N	\N	2020-10-29 13:33:23.026883	\N	\N	\N	\N	2020-10-29 13:33:23.027395	2020-10-29 13:33:23.027395	\N	\N
c59f7383-59cb-4941-9fbc-29d0083dbca8	Örtlichkeit	\N	\N	\N	2020-10-29 13:33:23.046517	\N	\N	\N	\N	2020-10-29 13:33:23.047054	2020-10-29 13:33:23.047054	\N	\N
15753fb5-bf53-4482-a20f-81669bb11b1c	Piste	\N	\N	\N	2020-10-29 13:33:23.064724	\N	\N	\N	\N	2020-10-29 13:33:23.06527	2020-10-29 13:33:23.06527	\N	\N
ab1d3fe9-ae29-466c-9a5f-d6af9f83ffbe	POI	\N	\N	\N	2020-10-29 13:33:23.118067	\N	\N	\N	\N	2020-10-29 13:33:23.119312	2020-10-29 13:33:23.119312	\N	\N
29580306-e06b-4556-8b69-31e27c5f3b2b	Tour	\N	\N	\N	2020-10-29 13:33:23.150538	\N	\N	\N	\N	2020-10-29 13:33:23.151273	2020-10-29 13:33:23.151273	\N	\N
33c6bc95-6125-4fb6-943c-31912b12261d	Unterkunft	\N	\N	\N	2020-10-29 13:33:23.174169	\N	\N	\N	\N	2020-10-29 13:33:23.174838	2020-10-29 13:33:23.174838	\N	\N
988d2866-6f9a-4301-a5a5-7453269cae5e	LocalBusiness	\N	\N	\N	2020-10-29 13:33:23.196623	\N	\N	\N	\N	2020-10-29 13:33:23.197268	2020-10-29 13:33:23.197268	\N	\N
5bf02cc5-0a09-43e9-b840-7f44663294a4	Gastronomischer Betrieb	\N	\N	\N	2020-10-29 13:33:23.218757	\N	\N	\N	\N	2020-10-29 13:33:23.21941	2020-10-29 13:33:23.21941	\N	\N
1c621586-39b8-4701-9508-6d048eff5095	Artikel	\N	\N	\N	2020-10-29 13:33:23.263589	\N	\N	\N	\N	2020-10-29 13:33:23.264377	2020-10-29 13:33:23.264377	\N	\N
f2bad979-52ab-4dda-bd32-fdfbfb90c233	Beschreibungstext	\N	\N	\N	2020-10-29 13:33:23.288406	\N	\N	\N	\N	2020-10-29 13:33:23.289138	2020-10-29 13:33:23.289138	\N	\N
cb97b34e-7b91-4f68-af46-53ed7b8526c2	Katalog	\N	\N	\N	2020-10-29 13:33:23.312866	\N	\N	\N	\N	2020-10-29 13:33:23.313651	2020-10-29 13:33:23.313651	\N	\N
b7be0b1f-1794-44d4-bf95-4cbbfbf5d94f	Organisation	\N	\N	\N	2020-10-29 13:33:23.337237	\N	\N	\N	\N	2020-10-29 13:33:23.337784	2020-10-29 13:33:23.337784	\N	\N
2cce1928-5d2d-4119-bb59-78000a2deec9	Person	\N	\N	\N	2020-10-29 13:33:23.355712	\N	\N	\N	\N	2020-10-29 13:33:23.356205	2020-10-29 13:33:23.356205	\N	\N
564b1620-1f0f-452f-b72b-3b2d7d86a906	Pauschalangebot	\N	\N	\N	2020-10-29 13:33:23.374182	\N	\N	\N	\N	2020-10-29 13:33:23.374755	2020-10-29 13:33:23.374755	\N	\N
45d4a693-d742-4526-93ee-6bd5cd6e3733	Produkte	\N	\N	\N	2020-10-29 13:33:23.391089	\N	\N	\N	\N	2020-10-29 13:33:23.391612	2020-10-29 13:33:23.391612	\N	\N
11349229-a429-4419-8642-eb0468407bda	Produkt	\N	\N	\N	2020-10-29 13:33:23.408127	\N	\N	\N	\N	2020-10-29 13:33:23.408584	2020-10-29 13:33:23.408584	\N	\N
9014ee8e-7dd9-4298-9dea-744768dd718f	Produktgruppe	\N	\N	\N	2020-10-29 13:33:23.425982	\N	\N	\N	\N	2020-10-29 13:33:23.426423	2020-10-29 13:33:23.426423	\N	\N
2cdcebb4-177f-4292-9025-f777c6ead56b	Produktmodel	\N	\N	\N	2020-10-29 13:33:23.442832	\N	\N	\N	\N	2020-10-29 13:33:23.443282	2020-10-29 13:33:23.443282	\N	\N
4412a70a-a21c-4c20-b64e-9834ffbf80f3	Service	\N	\N	\N	2020-10-29 13:33:23.459356	\N	\N	\N	\N	2020-10-29 13:33:23.459807	2020-10-29 13:33:23.459807	\N	\N
d7a8239f-f83d-4628-97ee-d727daf7d07b	Veranstaltung	\N	\N	\N	2020-10-29 13:33:23.476346	\N	\N	\N	\N	2020-10-29 13:33:23.476803	2020-10-29 13:33:23.476803	\N	\N
b8cbed4c-5b09-4577-95a4-27705f9b24a3	Veranstaltungsserie	\N	\N	\N	2020-10-29 13:33:23.494289	\N	\N	\N	\N	2020-10-29 13:33:23.494665	2020-10-29 13:33:23.494665	\N	\N
9953cd1c-5fca-4dd3-bdb3-8a8d95419041	Zimmer	\N	\N	\N	2020-10-29 13:33:23.51118	\N	\N	\N	\N	2020-10-29 13:33:23.511549	2020-10-29 13:33:23.511549	\N	\N
62b90969-141e-48df-9598-b1d105786542	Veranstaltungstermin	\N	\N	\N	2020-10-29 13:33:23.528079	\N	\N	\N	\N	2020-10-29 13:33:23.528566	2020-10-29 13:33:23.528566	\N	\N
1d8fde4f-3543-4138-88cd-07cdc2fa9a7a	Öffnungszeit	\N	\N	\N	2020-10-29 13:33:23.545346	\N	\N	\N	\N	2020-10-29 13:33:23.545738	2020-10-29 13:33:23.545738	\N	\N
d1571300-0ba3-4620-b120-0d690ece7432	Öffnungszeit - Simple	\N	\N	\N	2020-10-29 13:33:23.562163	\N	\N	\N	\N	2020-10-29 13:33:23.562598	2020-10-29 13:33:23.562598	\N	\N
ca493cd1-4a4d-43f8-8537-28908f7193f9	Öffnungszeit - Zeitspanne	\N	\N	\N	2020-10-29 13:33:23.578542	\N	\N	\N	\N	2020-10-29 13:33:23.578982	2020-10-29 13:33:23.578982	\N	\N
911b4df8-a802-45c4-a38f-eebaa3f511d3	Overlay	\N	\N	\N	2020-10-29 13:33:23.595149	\N	\N	\N	\N	2020-10-29 13:33:23.595703	2020-10-29 13:33:23.595703	\N	\N
d4a176f1-8929-4cca-a8e4-1f28e3d46ac1	Publikations-Plan	\N	\N	\N	2020-10-29 13:33:23.615927	\N	\N	\N	\N	2020-10-29 13:33:23.616527	2020-10-29 13:33:23.616527	\N	\N
e37af862-0995-49bf-a229-2fa38091b5f8	EventSchedule	\N	\N	\N	2020-10-29 13:33:23.635535	\N	\N	\N	\N	2020-10-29 13:33:23.636112	2020-10-29 13:33:23.636112	\N	\N
2251ea8d-0021-4089-aadf-3a883be2f433	Text	\N	\N	\N	2020-10-29 13:33:23.683427	\N	\N	\N	\N	2020-10-29 13:33:23.241647	2020-10-29 13:33:23.684432	\N	\N
60c0dc66-33d7-4330-950c-d90162ec2d31	Strukturierter Artikel	\N	\N	\N	2020-10-29 13:33:23.704432	\N	\N	\N	\N	2020-10-29 13:33:23.705422	2020-10-29 13:33:23.705422	\N	\N
23dd8bb7-0ba3-48f4-8586-325b77b85d71	Rezept	\N	\N	\N	2020-10-29 13:33:23.726506	\N	\N	\N	\N	2020-10-29 13:33:23.727134	2020-10-29 13:33:23.727134	\N	\N
7b336aad-daaf-429f-b1a9-3fe8ade5759d	Inhaltsblock	\N	\N	\N	2020-10-29 13:33:23.752684	\N	\N	\N	\N	2020-10-29 13:33:23.75328	2020-10-29 13:33:23.75328	\N	\N
05190f5a-f776-4b20-8b85-5430c650e2f0	Rezeptkomponente	\N	\N	\N	2020-10-29 13:33:23.784653	\N	\N	\N	\N	2020-10-29 13:33:23.785248	2020-10-29 13:33:23.785248	\N	\N
b337bd99-d9c7-4fe6-bb02-3dded529d126	Zutat	\N	\N	\N	2020-10-29 13:33:23.806599	\N	\N	\N	\N	2020-10-29 13:33:23.807175	2020-10-29 13:33:23.807175	\N	\N
cd259949-2a3b-4b4f-ae67-10073c3cdabe	Asset	\N	\N	\N	2020-10-29 13:33:23.830199	\N	\N	\N	\N	2020-10-29 13:33:22.931924	2020-10-29 13:33:23.831058	\N	\N
02c85def-1fc4-416e-9530-9e4c567edf2e	Audio	\N	\N	\N	2020-10-29 13:33:23.845406	\N	\N	\N	\N	2020-10-29 13:33:23.845875	2020-10-29 13:33:23.845875	\N	\N
91571c39-c843-4ece-b71f-42ec8ba81c52	Bild	\N	\N	\N	2020-10-29 13:33:23.865861	\N	\N	\N	\N	2020-10-29 13:33:22.963277	2020-10-29 13:33:23.866537	\N	\N
7ca63d7b-93e6-4b44-a28b-d0d627268cfd	Video	\N	\N	\N	2020-10-29 13:33:23.88246	\N	\N	\N	\N	2020-10-29 13:33:22.992044	2020-10-29 13:33:23.883096	\N	\N
89f99131-a057-4148-8041-cdd851b00977	Datei	\N	\N	\N	2020-10-29 13:33:23.897004	\N	\N	\N	\N	2020-10-29 13:33:23.89746	2020-10-29 13:33:23.89746	\N	\N
e561070d-3096-4132-87b5-d44b41720511	PDF	\N	\N	\N	2020-10-29 13:33:23.916722	\N	\N	\N	\N	2020-10-29 13:33:23.917257	2020-10-29 13:33:23.917257	\N	\N
150f501e-fadf-4e56-bc94-338bd3028352	Ort	\N	\N	\N	2020-10-29 13:33:23.939259	\N	\N	\N	\N	2020-10-29 13:33:23.009645	2020-10-29 13:33:23.940033	\N	\N
c07ec2c5-e77a-43b8-b2ee-00521079fb30	Badeseen	\N	\N	\N	2020-10-29 13:33:23.955294	\N	\N	\N	\N	2020-10-29 13:33:23.955787	2020-10-29 13:33:23.955787	\N	\N
c5977dba-5f26-436c-877f-98f2bd0e31e4	Skigebiet	\N	\N	\N	2020-10-29 13:33:23.973057	\N	\N	\N	\N	2020-10-29 13:33:23.973543	2020-10-29 13:33:23.973543	\N	\N
7fabf8f6-0e2b-49e4-8088-50d33ebea38e	freie Scheehöhenmesspunkte	\N	\N	\N	2020-10-29 13:33:23.992916	\N	\N	\N	\N	2020-10-29 13:33:23.993356	2020-10-29 13:33:23.993356	\N	\N
f0d787ba-6402-4303-8e9c-ea9ca8181532	Schneehöhe - Messpunkt	\N	\N	\N	2020-10-29 13:33:24.012872	\N	\N	\N	\N	2020-10-29 13:33:24.013471	2020-10-29 13:33:24.013471	\N	\N
e05c504c-f5c9-4a5e-a30b-a3cb0559636e	Skigebiet - Addon	\N	\N	\N	2020-10-29 13:33:24.034208	\N	\N	\N	\N	2020-10-29 13:33:24.034804	2020-10-29 13:33:24.034804	\N	\N
dfd48447-1cb2-4071-83de-6bc5310ae813	Job	\N	\N	\N	2020-10-29 13:33:24.057051	\N	\N	\N	\N	2020-10-29 13:33:24.057637	2020-10-29 13:33:24.057637	\N	\N
5c216505-b22a-4049-b4be-36a256156468	Zertifizierung	\N	\N	\N	2020-10-29 13:33:24.077012	\N	\N	\N	\N	2020-10-29 13:33:24.077513	2020-10-29 13:33:24.077513	\N	\N
a6e7219c-b8d5-4005-ac00-019aeb69e1c4	Reisen für Alle	\N	\N	\N	2020-10-29 13:33:24.095992	\N	\N	\N	\N	2020-10-29 13:33:24.096652	2020-10-29 13:33:24.096652	\N	\N
\.


--
-- TOC entry 4339 (class 0 OID 21672)
-- Dependencies: 228
-- Data for Name: content_content_histories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.content_content_histories (id, content_a_history_id, relation_a, content_b_history_id, content_b_history_type, history_valid, created_at, updated_at, order_a, relation_b) FROM stdin;
\.


--
-- TOC entry 4338 (class 0 OID 21661)
-- Dependencies: 227
-- Data for Name: content_contents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.content_contents (id, content_a_id, relation_a, content_b_id, created_at, updated_at, order_a, relation_b) FROM stdin;
\.


--
-- TOC entry 4330 (class 0 OID 21346)
-- Dependencies: 219
-- Data for Name: data_links; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.data_links (id, item_id, item_type, creator_id, seen_at, created_at, updated_at, permissions, receiver_id, comment, valid_from, valid_until, asset_id, locale) FROM stdin;
\.


--
-- TOC entry 4327 (class 0 OID 21188)
-- Dependencies: 216
-- Data for Name: delayed_jobs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.delayed_jobs (id, priority, attempts, handler, last_error, run_at, locked_at, failed_at, locked_by, queue, delayed_reference_id, delayed_reference_type, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4349 (class 0 OID 21957)
-- Dependencies: 240
-- Data for Name: external_system_syncs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.external_system_syncs (id, syncable_id, external_system_id, data, created_at, updated_at, status, syncable_type, last_sync_at, last_successful_sync_at, external_key, sync_type) FROM stdin;
\.


--
-- TOC entry 4348 (class 0 OID 21948)
-- Dependencies: 239
-- Data for Name: external_systems; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.external_systems (id, name, config, credentials, default_options, data, created_at, updated_at, identifier, last_download, last_successful_download, last_import, last_successful_import) FROM stdin;
\.


--
-- TOC entry 4332 (class 0 OID 21575)
-- Dependencies: 221
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.roles (id, name, rank, created_at, updated_at) FROM stdin;
43afbeb0-d11a-40de-8d24-d300c04348aa	super_admin	99	2020-10-29 13:32:45.251555	2020-10-29 13:32:45.251555
3022fcbe-b59a-432b-8b11-f387d6574a16	guest	0	2020-10-29 13:32:54.205219	2020-10-29 13:32:54.205219
d8a8ff7d-cc2c-4efe-97a6-9c6ce867e6e3	standard	5	2020-10-29 13:32:54.210631	2020-10-29 13:32:54.210631
6b9097ae-6926-4b9d-b0c7-232daf1c7e48	admin	10	2020-10-29 13:32:54.215539	2020-10-29 13:32:54.215539
\.


--
-- TOC entry 4353 (class 0 OID 22092)
-- Dependencies: 249
-- Data for Name: schedule_histories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schedule_histories (id, thing_history_id, relation, dtstart, dtend, duration, rrule, rdate, exdate, external_source_id, external_key, seen_at, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4352 (class 0 OID 22081)
-- Dependencies: 248
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schedules (id, thing_id, relation, dtstart, dtend, duration, rrule, rdate, exdate, external_source_id, external_key, seen_at, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4318 (class 0 OID 20973)
-- Dependencies: 207
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schema_migrations (version) FROM stdin;
20170116165448
20170118091809
20170131141857
20170131145138
20170202142906
20170209101956
20170209115919
20170213144933
20170307094512
20170406115252
20170412124816
20170418141539
20170523115242
20170524132123
20170524144644
20170612114242
20170620143810
20170621070615
20170624083501
20170714114037
20170720130827
20170806152208
20170807100953
20170807131053
20170808071705
20170816140348
20170817090756
20170817151049
20170821072749
20170828102436
20170905152134
20170906131340
20170908143555
20170912133931
20170915000001
20170915000002
20170915000003
20170915000004
20170918093456
20170919085841
20170920071933
20170921160600
20170921161200
20170929140328
20171000124018
20171001084323
20171001123612
20171002085329
20171002132936
20171003142621
20171004072726
20171004114524
20171004120235
20171004125221
20171004132930
20171009130405
20171102091700
20171115121939
20171121084202
20171123083228
20171128091456
20171204092716
20171206163333
20180103144809
20180105085118
20180109095257
20180111111106
20180117073708
20180122153121
20180124091123
20180222091614
20180328122539
20180329064133
20180330063016
20180410220414
20180417130441
20180421162723
20180425110943
20180430064709
20180503125925
20180507073804
20180509130533
20180525083121
20180525084148
20180529105933
20180703135948
20180705133931
20180809084405
20180811125951
20180812123536
20180813133739
20180814141924
20180815132305
20180820064823
20180907080412
20180914085848
20180917085622
20180917103214
20180918085636
20180918135618
20180921083454
20180927090624
20180928084042
20181001000001
20181001085516
20181009131613
20181011125030
20181019075437
20181106113333
20181116090243
20181123113811
20181126000001
20181127142527
20181130130052
20181229111741
20181231081526
20190107074405
20190108154224
20190110092936
20190110151543
20190117135807
20190118113621
20190118145915
20190129083607
20190312141313
20190314094528
20190325122951
20190423083517
20190423103601
20190520124223
20190531093158
20190612084614
20190613092317
20190703082641
20190704114636
20190712074413
20190716081614
20190716130050
20190801120456
20190805085313
20190821101746
20190920075014
20190926131653
20191113092141
20191119110348
20191129131046
20191204141710
20191205123950
20191219123847
20191219143016
20200116143539
20200117095949
20200131103229
20200205143630
20200213132354
20200217100339
20200218132801
20200218151417
20200219111406
20200221115053
20200224143507
20200226121349
20200410064408
20200420130554
20200514064724
20200525104244
20200529140637
20200602070145
20200721111525
20200724094112
20200728062727
20200812110341
20200812111137
20200824121824
20200824140802
20200826082051
20200903102806
20200922112719
20200928122555
20201014110327
20201016100223
\.


--
-- TOC entry 4335 (class 0 OID 21605)
-- Dependencies: 224
-- Data for Name: searches; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.searches (id, content_data_id, locale, words, full_text, created_at, updated_at, headline, data_type, classification_string, validity_period, all_text, boost, schema_type, advanced_attributes, classification_aliases_mapping, classification_ancestors_mapping) FROM stdin;
fcdfcd6e-698a-4e5c-a71d-8932f9b8c142	9ac37e86-80b6-413f-b8f0-d960ffee22d1	de	'event':3 'test':2 'test-event':1	test-event	2020-10-29 13:34:35.929846	2020-10-29 13:34:40.153978	test-event	Event	 	[-infinity,infinity]	test-event  test-event	100	Event	{}	{e2281642-3bf1-4875-818c-f8686f3a385e}	{}
5d259c92-fa33-41a3-b3d0-ed5e2f03ade5	030312f0-c8c3-45da-bd65-0674b50aaddc	de	'poi':3 'test':2 'test-poi':1	test-poi	2020-10-29 13:35:03.122905	2020-10-29 13:35:17.392148	test-poi	POI	 	[-infinity,infinity]	test-poi  test-poi	10	Place	{"address.postal_code": ["s"], "address.street_address": ["s"], "address.address_country": ["f"], "address.address_locality": ["d"]}	{21ad2ac9-3441-47f5-bc42-90ea910ef3be}	{103512a5-8595-4528-b859-210a5021d531}
c27c0ae6-bffb-45af-a32a-fff4513f917d	48c72098-be3e-4779-977d-d9901ff4cbf9	de	'arrr':4 'rasdf':5 'test':2 'test-text':1 'text':3	test-text arrr <p>rasdf</p>	2020-10-29 13:35:54.703551	2020-10-29 13:36:05.133696	test-text	Strukturierter Artikel	freigegeben freigegeben	[-infinity,infinity]	test-text freigegeben freigegeben test-text arrr <p>rasdf</p>	100	CreativeWork	{}	{c193fabb-749a-4a84-af8d-6a630ab82b89,d96ea961-6bac-4a8d-9572-5fa5c2790a7a}	{9b18e490-806c-4ce5-b272-99f53c63f49f}
\.


--
-- TOC entry 3920 (class 0 OID 20031)
-- Dependencies: 203
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- TOC entry 4341 (class 0 OID 21702)
-- Dependencies: 230
-- Data for Name: stored_filters; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stored_filters (id, name, user_id, language, parameters, system, api, created_at, updated_at, api_users, linked_stored_filter_id, sort_parameters) FROM stdin;
24cdbe88-0ef9-4c55-8aa7-a4f5d550ac77	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[]	f	f	2020-10-29 13:34:19.523666	2020-10-29 13:34:19.99904	\N	\N	\N
d627c210-c704-4409-99d5-9966201ef84a	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"n": "Suchbegriff", "t": "fulltext_search", "v": "test"}]	f	f	2020-10-29 13:34:27.078623	2020-10-29 13:34:27.078623	\N	\N	[{"m": "fulltext_search", "o": "DESC", "v": "test"}]
f0590ef3-b64e-4e1c-a224-01b66d2f803a	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"n": "Suchbegriff", "t": "fulltext_search", "v": "test-event"}]	f	f	2020-10-29 13:34:29.524966	2020-10-29 13:34:52.344045	\N	\N	[{"m": "fulltext_search", "o": "DESC", "v": "test-event"}]
71f62b5f-2504-4c5c-8704-95d6fc561cb3	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"n": "Suchbegriff", "t": "fulltext_search", "v": "test-poi"}]	f	f	2020-10-29 13:34:55.179504	2020-10-29 13:35:16.583585	\N	\N	[{"m": "fulltext_search", "o": "DESC", "v": "test-poi"}]
88faba65-0964-454c-bf2c-bf7ec18ac794	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"n": "Suchbegriff", "t": "fulltext_search", "v": "test-text"}]	f	f	2020-10-29 13:35:47.828142	2020-10-29 13:36:03.456936	\N	\N	[{"m": "fulltext_search", "o": "DESC", "v": "test-text"}]
33bcdf40-2895-4aa5-8cd3-f0d627f8f6c8	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[]	f	f	2020-10-29 13:36:05.655769	2020-10-29 13:36:05.655769	\N	\N	\N
94e6a41a-0f4f-4497-ac29-c87f15628815	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"c": "a", "m": "e", "n": "Inhaltstypen", "t": "classification_alias_ids", "v": ["9b18e490-806c-4ce5-b272-99f53c63f49f"]}]	f	f	2020-10-29 13:36:17.063647	2020-10-29 13:36:17.063647	\N	\N	\N
ff94cbbd-e749-47f2-9bfa-b864b336b34e	no_text	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"c": "a", "m": "e", "n": "Inhaltstypen", "t": "classification_alias_ids", "v": ["9b18e490-806c-4ce5-b272-99f53c63f49f"]}]	f	t	2020-10-29 13:36:26.814903	2020-10-29 13:36:35.752564	{"",e123d2d0-a678-4a95-b447-be62ca039ddf}	\N	\N
ad8dcbca-5821-410c-b574-fe0ab9015cba	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"c": "a", "m": "i", "n": "Inhaltstypen", "t": "classification_alias_ids", "v": ["eb67d4b7-8bb1-4101-806c-18f4f8f97fc4", "d02ae872-0768-4d0d-814f-90d3d131bef1"]}]	f	f	2020-10-30 08:36:47.857107	2020-10-30 10:44:48.306975	\N	\N	\N
e00587e7-74eb-4b60-bd3a-78148bf4d7dd	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[]	f	f	2020-10-30 11:34:28.133201	2020-10-30 11:34:28.133201	\N	\N	\N
b969c6e3-11d5-4fe3-8216-8a3e5c1441f1	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"n": "Suchbegriff", "t": "fulltext_search", "v": "noch ein Filter"}]	f	f	2020-10-30 11:34:34.985383	2020-10-30 11:34:34.985383	\N	\N	[{"m": "fulltext_search", "o": "DESC", "v": "noch ein Filter"}]
92b4ceb0-d5e2-4b52-b2d9-bd44f354b52e	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[]	f	f	2020-10-30 11:34:38.407443	2020-10-30 11:34:38.407443	\N	\N	\N
f3ee5e2a-0077-4519-a1ed-63a8d96508c9	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"c": "d", "m": "i", "n": "Inhaltstypen", "t": "classification_alias_ids", "v": ["e2281642-3bf1-4875-818c-f8686f3a385e"]}]	f	f	2020-10-30 11:34:44.625795	2020-10-30 11:34:44.625795	\N	\N	\N
5d890938-42b4-4a92-955d-7c3c0d0cd5de	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[]	f	f	2020-10-30 11:34:46.959046	2020-10-30 11:34:47.535169	\N	\N	\N
4e043d8e-c030-451a-a273-a72309f9838e	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"c": "d", "m": "i", "n": "Inhaltstypen", "t": "classification_alias_ids", "v": ["e2281642-3bf1-4875-818c-f8686f3a385e"]}]	f	f	2020-10-30 11:34:50.460324	2020-10-30 11:34:50.460324	\N	\N	\N
0c2cdd5b-2a42-4a93-bc11-d7b8de67ed15	event_only	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[{"c": "d", "m": "i", "n": "Inhaltstypen", "t": "classification_alias_ids", "v": ["e2281642-3bf1-4875-818c-f8686f3a385e"]}]	f	t	2020-10-30 11:34:56.92955	2020-10-30 13:29:10.269475	{"",e123d2d0-a678-4a95-b447-be62ca039ddf}	\N	\N
171fdcec-2c07-4223-832a-1338f6470220	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	{de}	[]	f	f	2020-10-30 13:29:12.991277	2020-10-30 13:29:37.259014	\N	\N	\N
\.


--
-- TOC entry 4331 (class 0 OID 21368)
-- Dependencies: 220
-- Data for Name: subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.subscriptions (id, user_id, subscribable_id, subscribable_type, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4350 (class 0 OID 22006)
-- Dependencies: 245
-- Data for Name: thing_duplicates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.thing_duplicates (id, thing_id, thing_duplicate_id, method, score, false_positive, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4346 (class 0 OID 21896)
-- Dependencies: 236
-- Data for Name: thing_histories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.thing_histories (id, thing_id, metadata, template_name, schema, template, internal_name, external_source_id, external_key, created_by, updated_by, deleted_by, template_updated_at, created_at, updated_at, deleted_at, given_name, family_name, start_date, end_date, longitude, latitude, elevation, location, line, address_locality, street_address, postal_code, address_country, fax_number, telephone, email, is_part_of, validity_range, boost, content_type, representation_of_id) FROM stdin;
ffb5ff24-f177-4f58-b5d2-9717cb1c8585	030312f0-c8c3-45da-bd65-0674b50aaddc	{"address": {"postal_code": null, "street_address": null, "address_country": null, "address_locality": null}, "license": null, "date_created": null, "date_deleted": null, "date_modified": null, "attribution_url": null, "attribution_name": null, "country_code_api": null, "more_permissions": null}	POI	{"api": {"type": "TouristAttraction"}, "name": "POI", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 20, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 17, "storage_location": "translated_value"}, "tour": {"api": {"disabled": true}, "type": "linked", "label": "Touren", "sorting": 30, "inverse_of": "poi", "template_name": "Tour", "link_direction": "inverse"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 19, "template_name": "Bild"}, "price": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Preis", "sorting": 26, "external": true, "storage_location": "translated_value"}, "stars": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Sterne", "sorting": 51, "external": true, "tree_label": "Feratel - Sterne"}, "author": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Autor", "sorting": 25, "external": true, "storage_location": "translated_value"}, "source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Quelle", "sorting": 36, "external": true, "tree_label": "OutdoorActive - Quellen", "not_translated": true}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 8, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 62, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "parking": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Parkmöglichkeit", "search": true, "sorting": 28, "external": true, "storage_location": "translated_value"}, "regions": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Regionen", "sorting": 35, "external": true, "tree_label": "OutdoorActive - Regionen"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 12, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 14, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 41, "tree_label": "Inhaltstypen", "default_value": "POI"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 13, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 11, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "directions": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Anfahrtsbeschreibung", "search": true, "sorting": 27, "external": true, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 21, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 16, "storage_location": "column"}, "price_range": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}}, "type": "string", "label": "Preis-Info", "search": true, "sorting": 24, "storage_location": "translated_value"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 15, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 9, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 69, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 71, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 72, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 23, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 22, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "poi_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Kategorie", "sorting": 39, "tree_label": "POI - Kategorien"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 70, "storage_location": "value"}, "feratel_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturtypen", "sorting": 48, "external": true, "tree_label": "Feratel - Infrastrukturtypen"}, "frontend_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Frontend-Typ", "sorting": 31, "external": true, "tree_label": "OutdoorActive - FrontendTypes", "not_translated": true}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 18, "validations": {"max": 1}, "template_name": "Bild"}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 52, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 53, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "feratel_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturklassifizierungen", "sorting": 49, "external": true, "tree_label": "Feratel - Infrastrukturklassifizierungen"}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 42, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "poi_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 33, "external": true, "tree_label": "OutdoorActive - POI-Kategorien"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 66, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 65, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 57, "tree_label": "Externer Status", "not_translated": true}, "hours_available": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Service-Zeiten", "sorting": 29, "external": true, "storage_location": "translated_value"}, "tour_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 32, "external": true, "tree_label": "OutdoorActive - Touren-Kategorien"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 64, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 10, "storage_location": "value"}, "feratel_cps_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Typ", "sorting": 59, "external": true, "tree_label": "Feratel CPS - Typen"}, "marketing_groups": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Marketinggruppen", "sorting": 54, "external": true, "tree_label": "Feratel - Marketinggruppen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 63, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 40, "translated": true, "template_name": "Action"}, "wogehmahin_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Types", "sorting": 61, "external": true, "tree_label": "Wogehmahin - Types"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 50, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "wogehmahin_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Topics", "sorting": 60, "external": true, "tree_label": "Wogehmahin - Topics"}, "feratel_cps_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Status", "sorting": 58, "external": true, "tree_label": "Feratel CPS - Stati"}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 45, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "outdoor_active_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Tags", "sorting": 34, "external": true, "tree_label": "OutdoorActive - Tags", "not_translated": true}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 56, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "additional_information": {"api": {"name": "subject_of"}, "type": "embedded", "label": "Ergänzende Information", "sorting": 4, "translated": false, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 67, "tree_label": "Lizenzen"}, "feratel_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsklassifizierungen", "sorting": 44, "external": true, "tree_label": "Feratel - Unterkunftsklassifizierungen"}, "accommodation_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsarten", "sorting": 43, "external": true, "tree_label": "Feratel - Unterkunftsarten"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 55, "external": true, "tree_label": "Feratel - CreativeCommons"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 68, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 7, "translated": true, "template_name": "Öffnungszeit"}, "outdoor_active_system_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Kategorien", "global": true, "sorting": 37, "tree_label": "OutdoorActive - System - Kategorien"}, "feratel_facilities_accommodations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Unterkünfte", "sorting": 46, "external": true, "tree_label": "Feratel - Merkmale - Unterkünfte"}, "outdoor_active_system_source_keys": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Quellen", "global": true, "sorting": 38, "tree_label": "OutdoorActive - System - Quellen", "validations": {"max": 1}}, "feratel_facilities_additional_services": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Services", "sorting": 47, "external": true, "tree_label": "Feratel - Merkmale - Services"}}, "schema_type": "Place", "content_type": "entity"}	f	\N	\N	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	e123d2d0-a678-4a95-b447-be62ca039ddf	\N	\N	2020-10-29 13:35:13.772026	2020-10-29 13:35:13.772026	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	[-infinity,infinity]	10.0	entity	\N
60d94117-200e-4467-bb3e-8c40c20552d9	48c72098-be3e-4779-977d-d9901ff4cbf9	{"license": null, "date_created": null, "date_deleted": null, "date_modified": null, "attribution_url": null, "validity_period": {"valid_from": null, "valid_until": null}, "attribution_name": null, "more_permissions": null, "release_status_comment": null}	Strukturierter Artikel	{"api": {"type": "Article"}, "name": "Strukturierter Artikel", "type": "object", "boost": 100.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "releasable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Link", "search": true, "sorting": 19, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 4, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 8, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Fließtext", "search": true, "sorting": 15, "storage_location": "translated_value"}, "about": {"type": "linked", "label": "Hauptthema", "sorting": 12, "inverse_of": "subject_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie", "Unterkunft"], "treeLabel": "Inhaltstypen"}}]}, "image": {"type": "linked", "label": "Bilder", "sorting": 16, "template_name": "Bild"}, "video": {"type": "linked", "label": "Videos", "sorting": 17, "template_name": "Video"}, "author": {"type": "linked", "label": "Autor", "sorting": 14, "validations": {"max": 1}, "template_name": "Person"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "headline": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Headline", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 6, "storage_location": "translated_value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 20, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 23, "tree_label": "Inhaltstypen", "default_value": "Strukturierter Artikel"}, "link_name": {"api": {"v4": {"name": "linkName", "type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "name": "name"}, "type": "string", "label": "Linktitel", "search": true, "sorting": 11, "storage_location": "translated_value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 13, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 25, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 27, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 28, "storage_location": "column"}, "content_block": {"type": "embedded", "label": "Inhaltsblock", "sorting": 21, "template_name": "Inhaltsblock"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 26, "storage_location": "value"}, "internal_name": {"api": {"disabled": true}, "type": "string", "label": "Arbeitstitel", "search": true, "sorting": 5, "storage_location": "column"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 9, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 33, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 32, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 7, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 18, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 22, "translated": true, "template_name": "Action"}, "release_status_id": {"ui": {"edit": {"options": {"multiple": false, "data-allow-clear": false}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "classification", "label": "Status", "sorting": 2, "tree_label": "Release-Stati", "default_value": "freigegeben"}, "alternative_headline": {"type": "string", "label": "Unterüberschrift", "search": true, "sorting": 10, "storage_location": "translated_value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 34, "tree_label": "Lizenzen"}, "release_status_comment": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "none"}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "string", "label": "Kommentar", "sorting": 3, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 24, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	f	\N	\N	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	e123d2d0-a678-4a95-b447-be62ca039ddf	\N	\N	2020-10-29 13:36:00.657695	2020-10-29 13:36:00.657695	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	[-infinity,infinity]	100.0	entity	\N
\.


--
-- TOC entry 4347 (class 0 OID 21908)
-- Dependencies: 237
-- Data for Name: thing_history_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.thing_history_translations (id, thing_history_id, locale, content, name, description, history_valid, created_at, updated_at) FROM stdin;
ccf98881-3889-4858-9c10-80b49566800b	ffb5ff24-f177-4f58-b5d2-9717cb1c8585	de	{"text": null, "price": null, "author": null, "parking": null, "directions": null, "price_range": null, "contact_info": {"url": null, "name": null, "email": null, "telephone": null, "fax_number": null}, "use_guidelines": null, "hours_available": null, "feratel_content_score": null}	test-poi	\N	["2020-10-29 13:35:03.122905+00","2020-10-29 13:35:13.772026+00")	2020-10-29 13:35:13.912789	2020-10-29 13:35:13.912789
8582df6a-69d3-4df0-9c6b-320b18609fd2	60d94117-200e-4467-bb3e-8c40c20552d9	de	{"url": null, "text": null, "headline": "test-text", "keywords": null, "link_name": null, "use_guidelines": null, "alternative_headline": null}	test-text	\N	["2020-10-29 13:35:54.703551+00","2020-10-29 13:36:00.657696+00")	2020-10-29 13:36:00.705642	2020-10-29 13:36:00.705642
\.


--
-- TOC entry 4345 (class 0 OID 21883)
-- Dependencies: 235
-- Data for Name: thing_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.thing_translations (id, thing_id, locale, content, name, description, created_at, updated_at) FROM stdin;
6f5f4f8d-82ad-43d2-b85d-50e8b5b8725a	9ac37e86-80b6-413f-b8f0-d960ffee22d1	de	{"url": null, "same_as": null, "use_guidelines": null, "potential_action": null, "feratel_content_score": null}	test-event	\N	2020-10-29 13:34:36.114825	2020-10-29 13:34:36.114825
7ddaf28f-fe02-46cb-9f7f-3b54fee58fed	030312f0-c8c3-45da-bd65-0674b50aaddc	de	{"text": "", "price": null, "author": null, "parking": null, "directions": null, "price_range": "", "contact_info": {"url": null, "name": null, "email": null, "telephone": null, "fax_number": null}, "use_guidelines": null, "hours_available": null, "feratel_content_score": null}	test-poi		2020-10-29 13:35:03.258234	2020-10-29 13:35:13.954105
2c491d0c-e36b-4b48-ab37-1aa0d81a3465	48c72098-be3e-4779-977d-d9901ff4cbf9	de	{"url": "", "text": "", "headline": "test-text", "keywords": null, "link_name": "arrr", "use_guidelines": null, "alternative_headline": ""}	test-text	<p>rasdf</p>	2020-10-29 13:35:54.770075	2020-10-29 13:36:00.735054
\.


--
-- TOC entry 4344 (class 0 OID 21868)
-- Dependencies: 234
-- Data for Name: things; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.things (id, metadata, template_name, schema, template, internal_name, external_source_id, external_key, created_by, updated_by, deleted_by, template_updated_at, created_at, updated_at, deleted_at, given_name, family_name, start_date, end_date, longitude, latitude, elevation, location, line, address_locality, street_address, postal_code, address_country, fax_number, telephone, email, is_part_of, validity_range, boost, content_type, representation_of_id) FROM stdin;
5ce944a7-6a32-4da4-92d0-2a27a00a42af	\N	Action	{"api": {}, "name": "Action", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"type": "string", "label": "URL", "search": true, "sorting": 3, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "action_type": {"api": {"name": "@type", "partial": "string"}, "type": "classification", "label": "Typ", "sorting": 4, "tree_label": "ActionTypes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 6, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 8, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 9, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 7, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 5, "external": true, "universal": true}}, "schema_type": "Action", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.486369	2020-10-29 13:34:01.502724	2020-10-29 13:34:01.502724	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
770c0a41-2860-4f1f-99a1-4fb6a327e899	\N	Beschreibungstext	{"api": {"type": "Article"}, "name": "Beschreibungstext", "type": "object", "boost": 100.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "releasable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 4, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 9, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Fließtext", "search": true, "sorting": 11, "storage_location": "translated_value"}, "about": {"type": "linked", "label": "About", "sorting": 13, "inverse_of": "subject_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "image": {"type": "linked", "label": "Bilder", "sorting": 12, "template_name": "Bild"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 17, "external": true, "storage_location": "value"}, "headline": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Headline", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 6, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 15, "tree_label": "Inhaltstypen", "default_value": "Beschreibungstext"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 24, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 26, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 27, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 25, "storage_location": "value"}, "internal_name": {"api": {"disabled": true}, "type": "string", "label": "Arbeitstitel", "search": true, "sorting": 5, "storage_location": "column"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 10, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 21, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 20, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 7, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 19, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 18, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 14, "translated": true, "template_name": "Action"}, "release_status_id": {"ui": {"edit": {"options": {"multiple": false, "data-allow-clear": false}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "classification", "label": "Status", "sorting": 2, "tree_label": "Release-Stati", "default_value": "freigegeben"}, "type_of_description": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Beschreibungsart", "sorting": 8, "tree_label": "Beschreibungsarten"}, "publication_schedule": {"api": {"disabled": true}, "type": "embedded", "label": "Geplante Publikation", "sorting": 16, "features": {"publication_schedule": {"allowed": true}}, "translated": true, "validations": {"classifications": "no_conflicts"}, "template_name": "Publikations-Plan"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 22, "tree_label": "Lizenzen"}, "release_status_comment": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "none"}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "string", "label": "Kommentar", "sorting": 3, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 23, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.529994	2020-10-29 13:34:01.532538	2020-10-29 13:34:01.532538	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
4d25a2b2-b539-49a0-8733-05e75c5c2358	\N	Ergänzende Information	{"api": {}, "name": "Ergänzende Information", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Name", "search": true, "sorting": 3, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 8, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 7, "template_name": "Bild"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Text", "search": true, "sorting": 5, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 10, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 12, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 13, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 11, "storage_location": "value"}, "validity_schedule": {"api": {"v4": {"disabled": false}, "disabled": true}, "type": "schedule", "label": "Season", "sorting": 6}, "type_of_information": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Informationstyp", "sorting": 2, "tree_label": "Informationstypen"}, "alternative_headline": {"type": "string", "label": "Alternativer Name", "search": true, "sorting": 4, "storage_location": "translated_value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 9, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.544229	2020-10-29 13:34:01.54561	2020-10-29 13:34:01.54561	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
d8099063-c02d-4143-a42c-8966eab8f2bd	\N	Artikel	{"api": {"type": "Article"}, "name": "Artikel", "type": "object", "boost": 100.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "releasable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Link", "search": true, "sorting": 19, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 4, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 8, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Fließtext", "search": true, "sorting": 15, "storage_location": "translated_value"}, "about": {"type": "linked", "label": "Hauptthema", "sorting": 12, "inverse_of": "subject_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie", "Unterkunft"], "treeLabel": "Inhaltstypen"}}]}, "image": {"type": "linked", "label": "Bilder", "sorting": 16, "template_name": "Bild"}, "video": {"type": "linked", "label": "Videos", "sorting": 17, "template_name": "Video"}, "author": {"type": "linked", "label": "Autor", "sorting": 14, "validations": {"max": 1}, "template_name": "Person"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 24, "external": true, "storage_location": "value"}, "headline": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Headline", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 6, "storage_location": "translated_value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 20, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 22, "tree_label": "Inhaltstypen", "default_value": "Artikel"}, "link_name": {"api": {"v4": {"name": "linkName", "type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "name": "name"}, "type": "string", "label": "Linktitel", "search": true, "sorting": 11, "storage_location": "translated_value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 13, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 31, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 33, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 34, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 32, "storage_location": "value"}, "internal_name": {"api": {"disabled": true}, "type": "string", "label": "Arbeitstitel", "search": true, "sorting": 5, "storage_location": "column"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 9, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 28, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 27, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 7, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 26, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 18, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 25, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 21, "translated": true, "template_name": "Action"}, "release_status_id": {"ui": {"edit": {"options": {"multiple": false, "data-allow-clear": false}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "classification", "label": "Status", "sorting": 2, "tree_label": "Release-Stati", "default_value": "freigegeben"}, "alternative_headline": {"type": "string", "label": "Unterüberschrift", "search": true, "sorting": 10, "storage_location": "translated_value"}, "publication_schedule": {"api": {"disabled": true}, "type": "embedded", "label": "Geplante Publikation", "sorting": 23, "features": {"publication_schedule": {"allowed": true}}, "translated": true, "validations": {"classifications": "no_conflicts"}, "template_name": "Publikations-Plan"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 29, "tree_label": "Lizenzen"}, "release_status_comment": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "none"}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "string", "label": "Kommentar", "sorting": 3, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 30, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.563195	2020-10-29 13:34:01.566038	2020-10-29 13:34:01.566038	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
6a60736b-80cc-4d3a-a64d-6f328905bb72	\N	BildOverlay	{"api": {}, "name": "BildOverlay", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 5, "default_value": "do_not_show", "storage_location": "translated_value"}, "caption": {"type": "string", "label": "Bildunterschrift", "search": true, "sorting": 3, "storage_location": "translated_value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Beschreibung (ALT-Label)", "search": true, "sorting": 4, "storage_location": "column"}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.576602	2020-10-29 13:34:01.577582	2020-10-29 13:34:01.577582	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
4756e44a-e520-426e-bf5f-02287e388541	\N	Katalog	{"api": {"type": "DigitalDocument"}, "name": "Katalog", "type": "object", "boost": 100.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": false}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "releasable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Link", "search": true, "sorting": 19, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 4, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 8, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Fließtext", "search": true, "sorting": 15, "storage_location": "translated_value"}, "about": {"type": "linked", "label": "Hauptthema", "sorting": 12, "inverse_of": "subject_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie", "Unterkunft"], "treeLabel": "Inhaltstypen"}}]}, "image": {"type": "linked", "label": "Bilder", "sorting": 16, "template_name": "Bild"}, "video": {"type": "linked", "label": "Videos", "sorting": 17, "template_name": "Video"}, "author": {"type": "linked", "label": "Autor", "sorting": 14, "validations": {"max": 1}, "template_name": "Person"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 24, "external": true, "storage_location": "value"}, "headline": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Headline", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 6, "storage_location": "translated_value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 20, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 22, "tree_label": "Inhaltstypen", "default_value": "Katalog"}, "link_name": {"api": {"v4": {"name": "linkName", "type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "name": "name"}, "type": "string", "label": "Linktitel", "search": true, "sorting": 11, "storage_location": "translated_value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 13, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 31, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 33, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 34, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 32, "storage_location": "value"}, "internal_name": {"api": {"disabled": true}, "type": "string", "label": "Arbeitstitel", "search": true, "sorting": 5, "storage_location": "column"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 9, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 28, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 27, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 7, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 26, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 18, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 25, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 21, "translated": true, "template_name": "Action"}, "release_status_id": {"ui": {"edit": {"options": {"multiple": false, "data-allow-clear": false}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "classification", "label": "Status", "sorting": 2, "tree_label": "Release-Stati", "default_value": "freigegeben"}, "alternative_headline": {"type": "string", "label": "Unterüberschrift", "search": true, "sorting": 10, "storage_location": "translated_value"}, "publication_schedule": {"api": {"disabled": true}, "type": "embedded", "label": "Geplante Publikation", "sorting": 23, "features": {"publication_schedule": {"allowed": true}}, "translated": true, "validations": {"classifications": "no_conflicts"}, "template_name": "Publikations-Plan"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 29, "tree_label": "Lizenzen"}, "release_status_comment": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "none"}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "string", "label": "Kommentar", "sorting": 3, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 30, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.59749	2020-10-29 13:34:01.600036	2020-10-29 13:34:01.600036	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
100ff4d7-efef-4776-83b7-d252a83ce480	\N	Öffnungszeit	{"api": {"type": "OpeningHoursSpecification"}, "name": "Öffnungszeit", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "time": {"type": "embedded", "label": "Zeit", "sorting": 4, "translated": true, "template_name": "Öffnungszeit - Zeitspanne"}, "validity": {"ui": {"edit": {"type": "daterange"}}, "api": {"transformation": {"method": "unwrap"}}, "type": "object", "label": "Gültigkeit", "sorting": 2, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "gültig von", "sorting": 1, "validations": {"format": "date"}, "storage_location": "value"}, "valid_through": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "gültig bis", "sorting": 2, "validations": {"format": "date"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_through", "from": "valid_from"}}, "storage_location": "value"}, "day_of_week": {"api": {"v4": {"partial": "array"}, "partial": "day_of_week"}, "type": "classification", "label": "Wochentag", "sorting": 3, "tree_label": "Wochentage"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Text", "sorting": 5, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 7, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 9, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 10, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 8, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 6, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.612831	2020-10-29 13:34:01.614184	2020-10-29 13:34:01.614184	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
29fa9c67-f088-450e-84fe-2ae228a41632	\N	Öffnungszeit - Zeitspanne	{"api": {}, "name": "Öffnungszeit - Zeitspanne", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "opens": {"ui": {"edit": {"options": {"placeholder": "hh:mm"}}}, "type": "string", "label": "geöffnet von", "sorting": 2, "validations": {"pattern": "(^$|^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$|^24:00(:00)?$)"}, "storage_location": "value"}, "closes": {"ui": {"edit": {"options": {"placeholder": "hh:mm"}}}, "type": "string", "label": "geöffnet bis", "sorting": 3, "validations": {"pattern": "(^$|^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$|^24:00(:00)?$)"}, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 5, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 7, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 8, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 6, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 4, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.62415	2020-10-29 13:34:01.625366	2020-10-29 13:34:01.625366	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
5ddcbb6b-194f-445b-a4aa-bb3603201d3f	\N	Unterkunft	{"api": {"type": "LodgingBusiness"}, "name": "Unterkunft", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 18, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 15, "storage_location": "translated_value"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 17, "template_name": "Bild"}, "price": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Preis", "sorting": 32, "external": true, "storage_location": "translated_value"}, "stars": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Sterne", "sorting": 53, "external": true, "tree_label": "Feratel - Sterne"}, "author": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Autor", "sorting": 31, "external": true, "storage_location": "translated_value"}, "source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Quelle", "sorting": 41, "external": true, "tree_label": "OutdoorActive - Quellen", "not_translated": true}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 6, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "founder": {"type": "linked", "label": "Gastgeber", "sorting": 24, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 69, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "parking": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Parkmöglichkeit", "search": true, "sorting": 34, "external": true, "storage_location": "translated_value"}, "regions": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Regionen", "sorting": 40, "external": true, "tree_label": "OutdoorActive - Regionen"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 10, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 12, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 68, "tree_label": "Inhaltstypen", "default_value": "Unterkunft"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 11, "validations": {"format": "float"}, "storage_location": "column"}, "hrs_stars": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS - Stars", "sorting": 67, "external": true, "tree_label": "HRS - Stars"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 9, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "directions": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Anfahrtsbeschreibung", "search": true, "sorting": 33, "external": true, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 19, "inverse_of": "about", "link_direction": "inverse"}, "booking_url": {"api": {"v4": {"type": "OrderAction", "partial": "action", "transformation": {"name": "potentialAction", "method": "append"}}, "type": "OrderAction", "partial": "property_value", "transformation": {"name": "potentialAction", "method": "combine"}}, "type": "string", "label": "Booking.com - Buchungs URL", "sorting": 63, "external": true, "validations": {"format": "url"}, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 14, "storage_location": "column"}, "makes_offer": {"type": "embedded", "label": "Angebote", "sorting": 28, "translated": true, "template_name": "Angebot"}, "price_range": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Preis-Info", "search": true, "sorting": 29, "storage_location": "translated_value"}, "xamoom_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Xamoom - Tags", "sorting": 60, "external": true, "tree_label": "Xamoom - Tags"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 13, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 7, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 76, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 78, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 79, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 21, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 20, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 77, "storage_location": "value"}, "feratel_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturtypen", "sorting": 50, "external": true, "tree_label": "Feratel - Infrastrukturtypen"}, "frontend_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Frontend-Typ", "sorting": 36, "external": true, "tree_label": "OutdoorActive - FrontendTypes", "not_translated": true}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 16, "validations": {"max": 1}, "template_name": "Bild"}, "contains_place": {"type": "linked", "label": "Services", "sorting": 27, "translated": true, "template_name": "Zimmer"}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 54, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 55, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "feratel_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturklassifizierungen", "sorting": 51, "external": true, "tree_label": "Feratel - Infrastrukturklassifizierungen"}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 44, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "hrs_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS - Categories", "sorting": 64, "external": true, "tree_label": "HRS - Categories"}, "hrs_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS - Facilities", "sorting": 65, "external": true, "tree_label": "HRS - Facilities"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "poi_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 38, "external": true, "tree_label": "OutdoorActive - POI-Kategorien"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 73, "external": true, "storage_location": "translated_value"}, "amenity_feature": {"api": {"v4": {"disabled": false}, "disabled": true}, "type": "embedded", "label": "Zusätzliches Merkmal", "sorting": 80, "template_name": "AmenityFeature"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 72, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 59, "tree_label": "Externer Status", "not_translated": true}, "hours_available": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Service-Zeiten", "sorting": 35, "external": true, "storage_location": "translated_value"}, "number_of_rooms": {"type": "number", "label": "Anzahl Zimmer/Apartments/Stellplätze", "sorting": 25, "storage_location": "value"}, "tour_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 37, "external": true, "tree_label": "OutdoorActive - Touren-Kategorien"}, "aggregate_rating": {"type": "embedded", "label": "Durchschnittswertung", "sorting": 30, "translated": true, "template_name": "Durchschnittswertung"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 71, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 8, "storage_location": "value"}, "marketing_groups": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Marketinggruppen", "sorting": 56, "external": true, "tree_label": "Feratel - Marketinggruppen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 70, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 22, "translated": true, "template_name": "Action"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 52, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "hrs_target_groups": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS - Target-Groups", "sorting": 66, "external": true, "tree_label": "HRS - Target-Groups"}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 47, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "booking_hotel_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Booking.com - HotelTypes", "sorting": 61, "external": true, "tree_label": "Booking.com - HotelTypes"}, "outdoor_active_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Tags", "sorting": 39, "external": true, "tree_label": "OutdoorActive - Tags", "not_translated": true}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 58, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "additional_information": {"api": {"name": "subject_of"}, "type": "embedded", "label": "Ergänzende Information", "sorting": 23, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 74, "tree_label": "Lizenzen"}, "feratel_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsklassifizierungen", "sorting": 46, "external": true, "tree_label": "Feratel - Unterkunftsklassifizierungen"}, "accommodation_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsarten", "sorting": 45, "external": true, "tree_label": "Feratel - Unterkunftsarten"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 57, "external": true, "tree_label": "Feratel - CreativeCommons"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 75, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 26, "translated": true, "template_name": "Öffnungszeit"}, "booking_hotel_facility_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Booking.com - FacilityTypes", "sorting": 62, "external": true, "tree_label": "Booking.com - FacilityTypes"}, "outdoor_active_system_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Kategorien", "global": true, "sorting": 42, "tree_label": "OutdoorActive - System - Kategorien"}, "feratel_facilities_accommodations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Unterkünfte", "sorting": 48, "external": true, "tree_label": "Feratel - Merkmale - Unterkünfte"}, "outdoor_active_system_source_keys": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Quellen", "global": true, "sorting": 43, "tree_label": "OutdoorActive - System - Quellen", "validations": {"max": 1}}, "feratel_facilities_additional_services": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Services", "sorting": 49, "external": true, "tree_label": "Feratel - Merkmale - Services"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.165766	2020-10-29 13:34:02.171719	2020-10-29 13:34:02.171719	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
da58156d-b372-44c0-bcdc-68c2c6036dde	\N	Örtlichkeit	{"api": {}, "name": "Örtlichkeit", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 20, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 17, "storage_location": "translated_value"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 19, "template_name": "Bild"}, "price": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Preis", "sorting": 26, "external": true, "storage_location": "translated_value"}, "stars": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Sterne", "sorting": 45, "external": true, "tree_label": "Feratel - Sterne"}, "author": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Autor", "sorting": 25, "external": true, "storage_location": "translated_value"}, "source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Quelle", "sorting": 35, "external": true, "tree_label": "OutdoorActive - Quellen", "not_translated": true}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 8, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 56, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "parking": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Parkmöglichkeit", "search": true, "sorting": 28, "external": true, "storage_location": "translated_value"}, "regions": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Regionen", "sorting": 34, "external": true, "tree_label": "OutdoorActive - Regionen"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 12, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 14, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 55, "tree_label": "Inhaltstypen", "default_value": "Örtlichkeit"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 13, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 11, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "directions": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Anfahrtsbeschreibung", "search": true, "sorting": 27, "external": true, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 21, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 16, "storage_location": "column"}, "xamoom_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Xamoom - Tags", "sorting": 50, "external": true, "tree_label": "Xamoom - Tags"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 15, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 9, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 63, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 65, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 66, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 23, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 22, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 64, "storage_location": "value"}, "feratel_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturtypen", "sorting": 42, "external": true, "tree_label": "Feratel - Infrastrukturtypen"}, "frontend_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Frontend-Typ", "sorting": 30, "external": true, "tree_label": "OutdoorActive - FrontendTypes", "not_translated": true}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 18, "validations": {"max": 1}, "template_name": "Bild"}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 46, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 47, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "feratel_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturklassifizierungen", "sorting": 43, "external": true, "tree_label": "Feratel - Infrastrukturklassifizierungen"}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 36, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "poi_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 32, "external": true, "tree_label": "OutdoorActive - POI-Kategorien"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 60, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 59, "external": true, "storage_location": "value"}, "hours_available": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Service-Zeiten", "sorting": 29, "external": true, "storage_location": "translated_value"}, "tour_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 31, "external": true, "tree_label": "OutdoorActive - Touren-Kategorien"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 58, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 10, "storage_location": "value"}, "marketing_groups": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Marketinggruppen", "sorting": 48, "external": true, "tree_label": "Feratel - Marketinggruppen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 57, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 24, "translated": true, "template_name": "Action"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 44, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 39, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "outdoor_active_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Tags", "sorting": 33, "external": true, "tree_label": "OutdoorActive - Tags", "not_translated": true}, "additional_information": {"api": {"name": "subject_of"}, "type": "embedded", "label": "Ergänzende Information", "sorting": 4, "translated": false, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 61, "tree_label": "Lizenzen"}, "feratel_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsklassifizierungen", "sorting": 38, "external": true, "tree_label": "Feratel - Unterkunftsklassifizierungen"}, "piemonte_venue_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - VenueCategories", "sorting": 53, "external": true, "tree_label": "EventsPiemonte - VenueCategories"}, "wikidata_classification": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wikidata - Classification", "sorting": 54, "external": true, "tree_label": "Wikidata - Classification"}, "accommodation_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsarten", "sorting": 37, "external": true, "tree_label": "Feratel - Unterkunftsarten"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 49, "external": true, "tree_label": "Feratel - CreativeCommons"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 62, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 7, "translated": true, "template_name": "Öffnungszeit"}, "google_business_primary_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Google Business - Hauptkategorie", "sorting": 51, "external": true, "tree_label": "Google Business - Kategorien"}, "feratel_facilities_accommodations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Unterkünfte", "sorting": 40, "external": true, "tree_label": "Feratel - Merkmale - Unterkünfte"}, "google_business_additional_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Google Business - Zusätzliche Kategorien", "sorting": 52, "external": true, "tree_label": "Google Business - Kategorien"}, "feratel_facilities_additional_services": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Services", "sorting": 41, "external": true, "tree_label": "Feratel - Merkmale - Services"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.207717	2020-10-29 13:34:02.212091	2020-10-29 13:34:02.212091	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
c2a3b16c-9042-48b6-8c03-5f65d6416d00	\N	POI	{"api": {"type": "TouristAttraction"}, "name": "POI", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 20, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 17, "storage_location": "translated_value"}, "tour": {"api": {"disabled": true}, "type": "linked", "label": "Touren", "sorting": 30, "inverse_of": "poi", "template_name": "Tour", "link_direction": "inverse"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 19, "template_name": "Bild"}, "price": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Preis", "sorting": 26, "external": true, "storage_location": "translated_value"}, "stars": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Sterne", "sorting": 51, "external": true, "tree_label": "Feratel - Sterne"}, "author": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Autor", "sorting": 25, "external": true, "storage_location": "translated_value"}, "source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Quelle", "sorting": 36, "external": true, "tree_label": "OutdoorActive - Quellen", "not_translated": true}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 8, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 62, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "parking": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Parkmöglichkeit", "search": true, "sorting": 28, "external": true, "storage_location": "translated_value"}, "regions": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Regionen", "sorting": 35, "external": true, "tree_label": "OutdoorActive - Regionen"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 12, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 14, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 41, "tree_label": "Inhaltstypen", "default_value": "POI"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 13, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 11, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "directions": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Anfahrtsbeschreibung", "search": true, "sorting": 27, "external": true, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 21, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 16, "storage_location": "column"}, "price_range": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}}, "type": "string", "label": "Preis-Info", "search": true, "sorting": 24, "storage_location": "translated_value"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 15, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 9, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 69, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 71, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 72, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 23, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 22, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "poi_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Kategorie", "sorting": 39, "tree_label": "POI - Kategorien"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 70, "storage_location": "value"}, "feratel_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturtypen", "sorting": 48, "external": true, "tree_label": "Feratel - Infrastrukturtypen"}, "frontend_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Frontend-Typ", "sorting": 31, "external": true, "tree_label": "OutdoorActive - FrontendTypes", "not_translated": true}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 18, "validations": {"max": 1}, "template_name": "Bild"}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 52, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 53, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "feratel_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturklassifizierungen", "sorting": 49, "external": true, "tree_label": "Feratel - Infrastrukturklassifizierungen"}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 42, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "poi_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 33, "external": true, "tree_label": "OutdoorActive - POI-Kategorien"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 66, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 65, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 57, "tree_label": "Externer Status", "not_translated": true}, "hours_available": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Service-Zeiten", "sorting": 29, "external": true, "storage_location": "translated_value"}, "tour_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 32, "external": true, "tree_label": "OutdoorActive - Touren-Kategorien"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 64, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 10, "storage_location": "value"}, "feratel_cps_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Typ", "sorting": 59, "external": true, "tree_label": "Feratel CPS - Typen"}, "marketing_groups": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Marketinggruppen", "sorting": 54, "external": true, "tree_label": "Feratel - Marketinggruppen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 63, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 40, "translated": true, "template_name": "Action"}, "wogehmahin_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Types", "sorting": 61, "external": true, "tree_label": "Wogehmahin - Types"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 50, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "wogehmahin_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Topics", "sorting": 60, "external": true, "tree_label": "Wogehmahin - Topics"}, "feratel_cps_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Status", "sorting": 58, "external": true, "tree_label": "Feratel CPS - Stati"}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 45, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "outdoor_active_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Tags", "sorting": 34, "external": true, "tree_label": "OutdoorActive - Tags", "not_translated": true}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 56, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "additional_information": {"api": {"name": "subject_of"}, "type": "embedded", "label": "Ergänzende Information", "sorting": 4, "translated": false, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 67, "tree_label": "Lizenzen"}, "feratel_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsklassifizierungen", "sorting": 44, "external": true, "tree_label": "Feratel - Unterkunftsklassifizierungen"}, "accommodation_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsarten", "sorting": 43, "external": true, "tree_label": "Feratel - Unterkunftsarten"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 55, "external": true, "tree_label": "Feratel - CreativeCommons"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 68, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 7, "translated": true, "template_name": "Öffnungszeit"}, "outdoor_active_system_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Kategorien", "global": true, "sorting": 37, "tree_label": "OutdoorActive - System - Kategorien"}, "feratel_facilities_accommodations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Unterkünfte", "sorting": 46, "external": true, "tree_label": "Feratel - Merkmale - Unterkünfte"}, "outdoor_active_system_source_keys": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Quellen", "global": true, "sorting": 38, "tree_label": "OutdoorActive - System - Quellen", "validations": {"max": 1}}, "feratel_facilities_additional_services": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Services", "sorting": 47, "external": true, "tree_label": "Feratel - Merkmale - Services"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.241396	2020-10-29 13:34:02.245958	2020-10-29 13:34:02.245958	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
25843f64-1398-4ff8-a807-1797c665e9db	\N	Piste	{"api": {"type": ["TouristAttraction", "dcls:Slope"]}, "name": "Piste", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 19, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 16, "storage_location": "translated_value"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 18, "template_name": "Bild"}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 7, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 27, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 11, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 13, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 24, "tree_label": "Inhaltstypen", "default_value": "Piste"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 12, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 10, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 20, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 15, "storage_location": "column"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 14, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 8, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 34, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 36, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 37, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 22, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 21, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 35, "storage_location": "value"}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 17, "validations": {"max": 1}, "template_name": "Bild"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 31, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 9, "storage_location": "value"}, "feratel_cps_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Typ", "sorting": 26, "external": true, "tree_label": "Feratel CPS - Typen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 28, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 23, "translated": true, "template_name": "Action"}, "feratel_cps_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Status", "sorting": 25, "external": true, "tree_label": "Feratel CPS - Stati"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 32, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 33, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 6, "translated": true, "template_name": "Öffnungszeit"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.268091	2020-10-29 13:34:02.271106	2020-10-29 13:34:02.271106	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
13758d69-c359-4777-89c0-be518512a328	\N	Tour	{"api": {}, "name": "Tour", "type": "object", "boost": 100.0, "features": {"overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "poi": {"type": "linked", "label": "POIS", "sorting": 26, "inverse_of": "tour", "template_name": "POI"}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 11, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 8, "storage_location": "translated_value"}, "tour": {"ui": {"edit": {"type": "LineString", "options": {"data_upload": true}}}, "api": {"v4": {"name": "line", "transformation": {"name": "geo", "type": "GeoShape", "method": "nest"}}, "disabled": false}, "type": "geographic", "label": "Route", "sorting": 25, "storage_location": "value"}, "image": {"api": {"minimal": true}, "type": "linked", "label": "Bilder", "sorting": 10, "template_name": "Bild"}, "price": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Preis", "sorting": 14, "external": true, "storage_location": "translated_value"}, "ascent": {"type": "number", "label": "Aufstieg (m)", "sorting": 32, "storage_location": "value"}, "author": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Autor", "sorting": 13, "external": true, "storage_location": "translated_value"}, "length": {"type": "number", "label": "Länge (m)", "sorting": 36, "storage_location": "value"}, "source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Quelle", "sorting": 23, "external": true, "tree_label": "OutdoorActive - Quellen", "not_translated": true}, "descent": {"type": "number", "label": "Abstieg (m)", "sorting": 33, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 49, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "TourOverlay"}, "parking": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Parkmöglichkeit", "search": true, "sorting": 16, "external": true, "storage_location": "translated_value"}, "regions": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Regionen", "sorting": 22, "external": true, "tree_label": "OutdoorActive - Regionen"}, "duration": {"type": "number", "label": "Dauer (min)", "sorting": 37, "storage_location": "value"}, "location": {"ui": {"edit": {"disabled": true}}, "api": {"minimal": true}, "type": "geographic", "label": "GPS-Startkoordinaten", "sorting": 24, "storage_location": "value"}, "schedule": {"type": "embedded", "label": "Season", "sorting": 12, "translated": true, "template_name": "Schedule"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 48, "tree_label": "Inhaltstypen", "default_value": "Tour"}, "equipment": {"type": "string", "label": "Ausrüstung", "search": true, "sorting": 30, "storage_location": "translated_value"}, "directions": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Anfahrtsbeschreibung", "search": true, "sorting": 15, "external": true, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 47, "inverse_of": "about", "link_direction": "inverse"}, "suggestion": {"type": "string", "label": "Tipps", "search": true, "sorting": 31, "storage_location": "translated_value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 7, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 56, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 58, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 59, "storage_location": "column"}, "instructions": {"type": "string", "label": "Wegbeschreibung", "search": true, "sorting": 28, "storage_location": "translated_value"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 46, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 45, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "max_altitude": {"type": "number", "label": "Maximale Seehöhe (m)", "sorting": 35, "storage_location": "value"}, "min_altitude": {"type": "number", "label": "Minimale Seehöhe (m)", "sorting": 34, "storage_location": "value"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 57, "storage_location": "value"}, "frontend_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Frontend-Typ", "sorting": 18, "external": true, "tree_label": "OutdoorActive - FrontendTypes", "not_translated": true}, "primary_image": {"api": {"v4": {"name": "photo"}, "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 9, "validations": {"max": 1}, "template_name": "Bild"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "poi_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 20, "external": true, "tree_label": "OutdoorActive - POI-Kategorien"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 53, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 52, "external": true, "storage_location": "value"}, "hours_available": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Service-Zeiten", "sorting": 17, "external": true, "storage_location": "translated_value"}, "tour_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 19, "external": true, "tree_label": "OutdoorActive - Touren-Kategorien"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 51, "external": true, "storage_location": "value"}, "condition_rating": {"type": "number", "label": "Bewertung - Kondition", "sorting": 38, "storage_location": "value"}, "landscape_rating": {"type": "number", "label": "Bewertung - Landschaft", "sorting": 41, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 50, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 44, "translated": true, "template_name": "Action"}, "technique_rating": {"type": "number", "label": "Bewertung - Technik", "sorting": 42, "storage_location": "value"}, "difficulty_rating": {"type": "number", "label": "Bewertung - Schwierigkeit", "sorting": 39, "storage_location": "value"}, "experience_rating": {"type": "number", "label": "Bewertung - Erlebnis", "sorting": 40, "storage_location": "value"}, "outdoor_active_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Tags", "sorting": 21, "external": true, "tree_label": "OutdoorActive - Tags", "not_translated": true}, "safety_instructions": {"type": "string", "label": "Sicherheitshinweis", "search": true, "sorting": 29, "storage_location": "translated_value"}, "additional_information": {"api": {"name": "subject_of"}, "type": "embedded", "label": "Ergänzende Information", "sorting": 4, "translated": false, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 54, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 55, "external": true, "universal": true}, "directions_public_transport": {"type": "string", "label": "Anfahrt mit öffentlichen Verkehrsmitteln", "search": true, "sorting": 27, "storage_location": "translated_value"}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 43, "translated": true, "template_name": "Öffnungszeit"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.293667	2020-10-29 13:34:02.296752	2020-10-29 13:34:02.296752	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
5e4ce175-b4c9-4e25-811a-9365cf25d359	\N	See	{"api": {"type": "BodyOfWater"}, "name": "See", "type": "object", "boost": 100.0, "features": {"overlay": {"allowed": true}, "download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"v4": {"name": "sameAs"}}, "type": "string", "label": "Link", "sorting": 15, "storage_location": "translated_value"}, "area": {"ui": {"edit": {"options": {"data-unit": "km²"}}, "show": {"options": {"data-unit": "km²"}}}, "api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}}, "type": "number", "label": "Fläche", "sorting": 8, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 3, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "depth": {"ui": {"edit": {"options": {"data-unit": "m"}}, "show": {"options": {"data-unit": "m"}}}, "api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}}, "type": "number", "label": "Tiefe", "sorting": 9, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 16, "template_name": "Bild"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 23, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 2, "validations": {"max": 1}, "template_name": "BodyOfWaterOverlay"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 11, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 13, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 17, "tree_label": "Inhaltstypen", "default_value": "Badeseen"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 12, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 10, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "water_temp": {"api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}}, "type": "object", "label": "Seetemperatur", "sorting": 7, "properties": {"quality": {"type": "string", "label": "Wasserqualität", "sorting": 3, "storage_location": "value"}, "temp_at": {"ui": {"edit": {"type": "datetime", "options": {"class": "single_date", "placeholder": "tt.mm.jjjj --:--"}}}, "type": "datetime", "label": "vom", "sorting": 2, "validations": {"format": "date_time"}, "advanced_search": true, "storage_location": "value"}, "temperature": {"ui": {"edit": {"options": {"data-unit": "°C"}}, "show": {"options": {"data-unit": "°C"}}}, "type": "number", "label": "Temperatur", "sorting": 1, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 19, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 21, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 22, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 20, "storage_location": "value"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "tourism_region": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tourismus-Region", "global": true, "sorting": 4, "tree_label": "Tourismus-Regionen"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 27, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 26, "external": true, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 25, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 24, "external": true, "storage_location": "value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 28, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 18, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 14, "translated": true, "template_name": "Öffnungszeit"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.318994	2020-10-29 13:34:02.321411	2020-10-29 13:34:02.321411	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
fc3f8fb1-4b65-4ce6-aa3f-96b79e7569b4	\N	Öffnungszeit - Simple	{"api": {"type": "OpeningHoursSpecification"}, "name": "Öffnungszeit - Simple", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "opens": {"ui": {"edit": {"options": {"placeholder": "hh:mm:ss"}}}, "type": "string", "label": "geöffnet von", "sorting": 4, "validations": {"pattern": "(^$|^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$)"}, "storage_location": "value"}, "closes": {"ui": {"edit": {"options": {"placeholder": "hh:mm:ss"}}}, "type": "string", "label": "geöffnet bis", "sorting": 5, "validations": {"pattern": "(^$|^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$)"}, "storage_location": "value"}, "validity": {"ui": {"edit": {"type": "daterange"}}, "api": {"transformation": {"method": "unwrap"}}, "type": "object", "label": "Gültigkeit", "sorting": 2, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "gültig von", "editor": {"type": "date", "options": {"data-type": "datepicker", "placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_through": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "gültig bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_through", "from": "valid_from"}}, "storage_location": "value"}, "day_of_week": {"type": "classification", "label": "Wochentag", "sorting": 3, "tree_label": "Wochentage"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 7, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 9, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 10, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 8, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 6, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.63525	2020-10-29 13:34:01.636671	2020-10-29 13:34:01.636671	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
d4d4a362-af30-4d20-b226-eed424c346b9	\N	PlaceOverlay	{"api": {}, "name": "PlaceOverlay", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 7, "template_name": "Bild"}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 4, "storage_location": "translated_value"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 14, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 6, "template_name": "Bild"}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 8, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 3, "storage_location": "column"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 11, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 9, "tree_label": "Ländercodes"}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 5, "validations": {"max": 1}, "template_name": "Bild"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 10, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 12, "translated": true, "template_name": "Action"}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 13, "translated": true, "template_name": "Öffnungszeit"}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.649297	2020-10-29 13:34:01.65118	2020-10-29 13:34:01.65118	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
6b7f4f12-07f8-4284-8996-6035ce2d005d	\N	Publikations-Plan	{"api": {}, "name": "Publikations-Plan", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "publish_at": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Publikationsdatum", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 5, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 7, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 8, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 6, "storage_location": "value"}, "output_channel": {"type": "classification", "label": "Ausgabekanäle", "sorting": 3, "tree_label": "Ausgabekanäle"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 4, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.660339	2020-10-29 13:34:01.661598	2020-10-29 13:34:01.661598	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
ab9c4945-4e6a-49f9-b974-955ff1b2e27f	\N	Schedule	{"api": {"type": "Schedule"}, "name": "Schedule", "type": "object", "boost": 1.0, "features": {"translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "by_month": {"type": "classification", "label": "Monat", "sorting": 3, "tree_label": "Monate"}, "day_of_week": {"api": {"name": "by_day"}, "type": "classification", "label": "Wochentag", "sorting": 2, "tree_label": "Wochentage"}, "by_month_day": {"type": "number", "label": "Tag im Monat", "sorting": 4, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 8, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 10, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 11, "storage_location": "column"}, "repeat_count": {"type": "number", "label": "Anzahl der Wiederholungen", "sorting": 5, "storage_location": "value"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 9, "storage_location": "value"}, "repeat_frequency": {"type": "string", "label": "Frequenz", "sorting": 6, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 7, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.675381	2020-10-29 13:34:01.676616	2020-10-29 13:34:01.676616	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
85953df9-7b14-40ec-8523-19c129467218	\N	TourOverlay	{"api": {}, "name": "TourOverlay", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 6, "template_name": "Bild"}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 8, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 5, "template_name": "Bild"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 3, "storage_location": "column"}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 4, "validations": {"max": 1}, "template_name": "Bild"}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 7, "translated": true, "template_name": "Öffnungszeit"}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.684296	2020-10-29 13:34:01.685379	2020-10-29 13:34:01.685379	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
fa4603fd-fbde-4cf4-b7e4-e1becd2cd602	\N	Inhaltsblock	{"api": {}, "name": "Inhaltsblock", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Überschrift", "search": true, "sorting": 2, "storage_location": "column"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Text", "search": true, "sorting": 4, "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 5, "template_name": "Bild"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 7, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 9, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 10, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 8, "storage_location": "value"}, "alternative_headline": {"type": "string", "label": "Unterüberschrift", "search": true, "sorting": 3, "storage_location": "translated_value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 6, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.692797	2020-10-29 13:34:01.69395	2020-10-29 13:34:01.69395	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
cc3f83bc-bbad-413a-bcc0-8171058d46c1	\N	Rezept	{"api": {"type": "Recipe"}, "name": "Rezept", "type": "object", "boost": 100.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "releasable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 4, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 10, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Fließtext", "search": true, "sorting": 17, "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 18, "template_name": "Bild"}, "author": {"type": "linked", "label": "Autor", "sorting": 13, "validations": {"max": 1}, "template_name": "Person"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 26, "external": true, "storage_location": "value"}, "headline": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Headline", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 6, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 20, "tree_label": "Inhaltstypen", "default_value": "Rezept"}, "total_time": {"ui": {"edit": {"type": "duration", "options": {"data-unit": "min"}}, "show": {"options": {"data-unit": "min"}}}, "api": {"format": {"append": "M", "prepend": "PT"}, "partial": "duration"}, "type": "number", "label": "Kochzeit", "sorting": 16, "validations": {"max": 300, "format": "integer"}, "advanced_search": true, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 12, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 22, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 24, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 25, "storage_location": "column"}, "recipe_yield": {"type": "string", "label": "Portionen", "search": true, "sorting": 15, "storage_location": "translated_value"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 23, "storage_location": "value"}, "internal_name": {"api": {"disabled": true}, "type": "string", "label": "Arbeitstitel", "search": true, "sorting": 5, "storage_location": "column"}, "recipe_course": {"type": "classification", "label": "Gang", "sorting": 9, "tree_label": "Gang (Rezept)"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 11, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 30, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "recipe_category": {"api": {"partial": "string"}, "type": "classification", "label": "Kategorie", "sorting": 8, "tree_label": "Rezeptkategorien"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 7, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 28, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 14, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Örtlichkeit", "POI", "Unterkunft", "LocalBusiness", "Gastronomischer Betrieb"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 27, "external": true, "storage_location": "value"}, "release_status_id": {"ui": {"edit": {"options": {"multiple": false, "data-allow-clear": false}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "classification", "label": "Status", "sorting": 2, "tree_label": "Release-Stati", "default_value": "freigegeben"}, "recipe_instructions": {"type": "embedded", "label": "Rezeptkomponente", "sorting": 19, "template_name": "Rezeptkomponente"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 31, "tree_label": "Lizenzen"}, "release_status_comment": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "none"}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "string", "label": "Kommentar", "sorting": 3, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 21, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.7077	2020-10-29 13:34:01.710091	2020-10-29 13:34:01.710091	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
030312f0-c8c3-45da-bd65-0674b50aaddc	{"address": {"postal_code": "s", "street_address": "s", "address_country": "f", "address_locality": "d"}, "license": null, "date_created": null, "date_deleted": null, "date_modified": null, "attribution_url": null, "attribution_name": null, "country_code_api": null, "more_permissions": null}	POI	{"api": {"type": "TouristAttraction"}, "name": "POI", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 20, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 17, "storage_location": "translated_value"}, "tour": {"api": {"disabled": true}, "type": "linked", "label": "Touren", "sorting": 30, "inverse_of": "poi", "template_name": "Tour", "link_direction": "inverse"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 19, "template_name": "Bild"}, "price": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Preis", "sorting": 26, "external": true, "storage_location": "translated_value"}, "stars": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Sterne", "sorting": 51, "external": true, "tree_label": "Feratel - Sterne"}, "author": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Autor", "sorting": 25, "external": true, "storage_location": "translated_value"}, "source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Quelle", "sorting": 36, "external": true, "tree_label": "OutdoorActive - Quellen", "not_translated": true}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 8, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 62, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "parking": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Parkmöglichkeit", "search": true, "sorting": 28, "external": true, "storage_location": "translated_value"}, "regions": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Regionen", "sorting": 35, "external": true, "tree_label": "OutdoorActive - Regionen"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 12, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 14, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 41, "tree_label": "Inhaltstypen", "default_value": "POI"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 13, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 11, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "directions": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Anfahrtsbeschreibung", "search": true, "sorting": 27, "external": true, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 21, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 16, "storage_location": "column"}, "price_range": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}}, "type": "string", "label": "Preis-Info", "search": true, "sorting": 24, "storage_location": "translated_value"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 15, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 9, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 69, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 71, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 72, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 23, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 22, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "poi_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Kategorie", "sorting": 39, "tree_label": "POI - Kategorien"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 70, "storage_location": "value"}, "feratel_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturtypen", "sorting": 48, "external": true, "tree_label": "Feratel - Infrastrukturtypen"}, "frontend_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Frontend-Typ", "sorting": 31, "external": true, "tree_label": "OutdoorActive - FrontendTypes", "not_translated": true}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 18, "validations": {"max": 1}, "template_name": "Bild"}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 52, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 53, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "feratel_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturklassifizierungen", "sorting": 49, "external": true, "tree_label": "Feratel - Infrastrukturklassifizierungen"}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 42, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "poi_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 33, "external": true, "tree_label": "OutdoorActive - POI-Kategorien"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 66, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 65, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 57, "tree_label": "Externer Status", "not_translated": true}, "hours_available": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Service-Zeiten", "sorting": 29, "external": true, "storage_location": "translated_value"}, "tour_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 32, "external": true, "tree_label": "OutdoorActive - Touren-Kategorien"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 64, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 10, "storage_location": "value"}, "feratel_cps_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Typ", "sorting": 59, "external": true, "tree_label": "Feratel CPS - Typen"}, "marketing_groups": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Marketinggruppen", "sorting": 54, "external": true, "tree_label": "Feratel - Marketinggruppen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 63, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 40, "translated": true, "template_name": "Action"}, "wogehmahin_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Types", "sorting": 61, "external": true, "tree_label": "Wogehmahin - Types"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 50, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "wogehmahin_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Topics", "sorting": 60, "external": true, "tree_label": "Wogehmahin - Topics"}, "feratel_cps_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Status", "sorting": 58, "external": true, "tree_label": "Feratel CPS - Stati"}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 45, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "outdoor_active_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Tags", "sorting": 34, "external": true, "tree_label": "OutdoorActive - Tags", "not_translated": true}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 56, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "additional_information": {"api": {"name": "subject_of"}, "type": "embedded", "label": "Ergänzende Information", "sorting": 4, "translated": false, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 67, "tree_label": "Lizenzen"}, "feratel_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsklassifizierungen", "sorting": 44, "external": true, "tree_label": "Feratel - Unterkunftsklassifizierungen"}, "accommodation_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsarten", "sorting": 43, "external": true, "tree_label": "Feratel - Unterkunftsarten"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 55, "external": true, "tree_label": "Feratel - CreativeCommons"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 68, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 7, "translated": true, "template_name": "Öffnungszeit"}, "outdoor_active_system_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Kategorien", "global": true, "sorting": 37, "tree_label": "OutdoorActive - System - Kategorien"}, "feratel_facilities_accommodations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Unterkünfte", "sorting": 46, "external": true, "tree_label": "Feratel - Merkmale - Unterkünfte"}, "outdoor_active_system_source_keys": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Quellen", "global": true, "sorting": 38, "tree_label": "OutdoorActive - System - Quellen", "validations": {"max": 1}}, "feratel_facilities_additional_services": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Services", "sorting": 47, "external": true, "tree_label": "Feratel - Merkmale - Services"}}, "schema_type": "Place", "content_type": "entity"}	f	\N	\N	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	e123d2d0-a678-4a95-b447-be62ca039ddf	\N	\N	2020-10-29 13:35:03.122905	2020-10-29 13:35:13.772026	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
896b5690-a1bf-495c-82fd-31ba04cab940	\N	Rezeptkomponente	{"api": {"type": "Recipe"}, "name": "Rezeptkomponente", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Name", "search": true, "sorting": 2, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 7, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 9, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 10, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 8, "storage_location": "value"}, "recipe_ingredient": {"api": {"v4": {"disabled": true}, "transformation": {"key": "name", "method": "map"}}, "type": "embedded", "label": "Zutat", "sorting": 4, "template_name": "Zutat"}, "recipe_instructions": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Anleitung", "sorting": 3, "storage_location": "translated_value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 6, "external": true, "universal": true}, "virtual_recipe_ingredient": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"name": "recipeIngredient", "disabled": false}, "disabled": true}, "type": "virtual", "label": "Virtual Recipe Ingredient", "sorting": 5, "virtual": {"key": "name", "type": "enum", "method": "map", "module": "Utility::Virtual::Embedded", "parameters": {"0": "recipe_ingredient"}}, "storage_location": "virtual"}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.722287	2020-10-29 13:34:01.72357	2020-10-29 13:34:01.72357	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
c4372b8d-e931-4805-b24d-4752a6c0bcd5	\N	Zutat	{"api": {}, "name": "Zutat", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Name und Menge", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 4, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 6, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 7, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 5, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 3, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.732484	2020-10-29 13:34:01.733529	2020-10-29 13:34:01.733529	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
db5a1a61-983f-406b-8549-503a044a800f	\N	Strukturierter Artikel	{"api": {"type": "Article"}, "name": "Strukturierter Artikel", "type": "object", "boost": 100.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "releasable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Link", "search": true, "sorting": 19, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 4, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 8, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Fließtext", "search": true, "sorting": 15, "storage_location": "translated_value"}, "about": {"type": "linked", "label": "Hauptthema", "sorting": 12, "inverse_of": "subject_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie", "Unterkunft"], "treeLabel": "Inhaltstypen"}}]}, "image": {"type": "linked", "label": "Bilder", "sorting": 16, "template_name": "Bild"}, "video": {"type": "linked", "label": "Videos", "sorting": 17, "template_name": "Video"}, "author": {"type": "linked", "label": "Autor", "sorting": 14, "validations": {"max": 1}, "template_name": "Person"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "headline": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Headline", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 6, "storage_location": "translated_value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 20, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 23, "tree_label": "Inhaltstypen", "default_value": "Strukturierter Artikel"}, "link_name": {"api": {"v4": {"name": "linkName", "type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "name": "name"}, "type": "string", "label": "Linktitel", "search": true, "sorting": 11, "storage_location": "translated_value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 13, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 25, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 27, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 28, "storage_location": "column"}, "content_block": {"type": "embedded", "label": "Inhaltsblock", "sorting": 21, "template_name": "Inhaltsblock"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 26, "storage_location": "value"}, "internal_name": {"api": {"disabled": true}, "type": "string", "label": "Arbeitstitel", "search": true, "sorting": 5, "storage_location": "column"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 9, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 33, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 32, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 7, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 18, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 22, "translated": true, "template_name": "Action"}, "release_status_id": {"ui": {"edit": {"options": {"multiple": false, "data-allow-clear": false}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "classification", "label": "Status", "sorting": 2, "tree_label": "Release-Stati", "default_value": "freigegeben"}, "alternative_headline": {"type": "string", "label": "Unterüberschrift", "search": true, "sorting": 10, "storage_location": "translated_value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 34, "tree_label": "Lizenzen"}, "release_status_comment": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "none"}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "string", "label": "Kommentar", "sorting": 3, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 24, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.746394	2020-10-29 13:34:01.748956	2020-10-29 13:34:01.748956	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
f9865bd2-c4a4-46e4-b81a-99ec266dd4d0	\N	Skigebiet - Addon	{"api": {"type": "LocationFeatureSpecification"}, "name": "Skigebiet - Addon", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"api": {"v4": {"name": "name"}, "name": "headline", "minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "text": {"api": {"name": "value", "minimal": true}, "type": "string", "label": "Text", "search": true, "sorting": 3, "storage_location": "value"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 4, "default_value": "do_not_show", "storage_location": "translated_value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 6, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 8, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 9, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 7, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 5, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.759232	2020-10-29 13:34:01.760386	2020-10-29 13:34:01.760386	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
9ec1566c-ff39-4ad1-af19-4449f6827b02	\N	Event	{"api": {}, "name": "Event", "type": "object", "boost": 100.0, "features": {"overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Inhalt URL", "sorting": 10, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 3, "normalize": {"id": "eventname", "type": "eventname"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "image": {"type": "linked", "label": "Bilder", "sorting": 12, "template_name": "Bild"}, "offers": {"type": "embedded", "label": "Angebote", "sorting": 23, "translated": true, "template_name": "Angebot"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 2, "validations": {"max": 1}, "template_name": "EventOverlay"}, "same_as": {"api": {"name": "link", "type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "xml": {"name": "link"}, "type": "string", "label": "Link", "sorting": 11, "validations": {"format": "url"}, "storage_location": "translated_value"}, "end_date": {"ui": {"show": {"content_area": "none"}}, "type": "computed", "label": "Endzeitpunkt", "compute": {"type": "datetime", "method": "end_date", "module": "Utility::Compute::Schedule", "parameters": {"0": "event_schedule"}}, "sorting": 8, "storage_location": "column"}, "schedule": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "eventSchedule"}, "type": "embedded", "label": "Event-Schedule", "sorting": 19, "translated": true, "template_name": "EventSchedule"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 30, "tree_label": "Inhaltstypen", "default_value": "Veranstaltung"}, "event_tag": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Veranstaltungsdatenbank - Tag", "sorting": 43, "external": true, "tree_label": "Veranstaltungsdatenbank - Tag"}, "organizer": {"type": "linked", "label": "Veranstalter", "sorting": 22, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "LocalBusiness"], "treeLabel": "Inhaltstypen"}}]}, "performer": {"type": "linked", "label": "Ausführende Person/Organisation", "sorting": 21, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "sub_event": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"v4": {"disabled": true}}, "type": "embedded", "label": "Veranstaltungsdaten", "sorting": 18, "template_name": "SubEvent"}, "start_date": {"ui": {"show": {"content_area": "none"}}, "type": "computed", "label": "Startzeitpunkt", "compute": {"type": "datetime", "method": "start_date", "module": "Utility::Compute::Schedule", "parameters": {"0": "event_schedule"}}, "sorting": 7, "storage_location": "column"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 27, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 9, "storage_location": "column"}, "puglia_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPuglia - Types", "sorting": 57, "external": true, "tree_label": "EventsPuglia - Types"}, "super_event": {"type": "linked", "label": "Veranstaltungsserie", "sorting": 20, "inverse_of": "sub_event", "template_name": "Eventserie"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 38, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 40, "storage_location": "value"}, "event_status": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"v4": {"partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Veranstaltungsstatus", "sorting": 16, "tree_label": "Veranstaltungsstatus"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 41, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 26, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 25, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "piemonte_tag": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - Tags", "sorting": 60, "external": true, "tree_label": "EventsPiemonte - Tags"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 39, "storage_location": "value"}, "v_ticket_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "V-Ticket Tags", "sorting": 45, "external": true, "tree_label": "VTicket - Tags"}, "event_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Veranstaltungsdatenbank - Kategorien", "sorting": 42, "external": true, "tree_label": "Veranstaltungsdatenbank - Kategorien"}, "event_schedule": {"api": {"v4": {"disabled": false}, "disabled": true}, "type": "schedule", "label": "Termine", "sorting": 17, "validations": {"valid_dates": true}}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 48, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 51, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 46, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "piemonte_scope": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - Scopes", "sorting": 62, "external": true, "tree_label": "EventsPiemonte - Scopes"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 35, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 34, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 29, "tree_label": "Externer Status", "not_translated": true}, "puglia_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPuglia - Categories", "sorting": 58, "external": true, "tree_label": "EventsPuglia - Categories"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 4, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 33, "external": true, "storage_location": "value"}, "content_location": {"api": {"name": "location"}, "type": "linked", "label": "Veranstaltungsort", "sorting": 13, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 32, "external": true, "storage_location": "value"}, "potential_action": {"api": {"type": "ViewAction", "partial": "action", "transformation": {"name": "potentialAction", "method": "append"}}, "type": "string", "label": "Link mit weiterführenden Infos", "sorting": 24, "storage_location": "translated_value"}, "virtual_location": {"api": {"v4": {"disabled": false, "transformation": {"name": "location", "method": "append"}}, "disabled": true}, "type": "embedded", "label": "Virtueller Veranstaltungsort", "sorting": 14, "template_name": "VirtualLocation"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 49, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "hrs_dd_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS Destination Data - Classifications", "sorting": 54, "external": true, "tree_label": "HRS Destination Data - Classifications"}, "piemonte_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - Categories", "sorting": 61, "external": true, "tree_label": "EventsPiemonte - Categories"}, "piemonte_coverage": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - Coverages", "sorting": 63, "external": true, "tree_label": "EventsPiemonte - Coverages"}, "feratel_event_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Veranstaltungstags", "sorting": 47, "external": true, "tree_label": "Feratel - Veranstaltungstags"}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 50, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "puglia_ticket_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPuglia - Ticket-Types", "sorting": 59, "external": true, "tree_label": "EventsPuglia - Ticket-Types"}, "v_ticket_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "V-Ticket Categories", "sorting": 44, "external": true, "tree_label": "VTicket - Categories"}, "piemonte_data_source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - DataSources", "sorting": 64, "external": true, "tree_label": "EventsPiemonte - DataSources"}, "event_attendance_mode": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"v4": {"partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Veranstaltungsteilnahmemodus", "sorting": 15, "tree_label": "Veranstaltungsteilnahmemodus"}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 28, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 36, "tree_label": "Lizenzen"}, "marche_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsMarche - Classifications", "sorting": 56, "external": true, "tree_label": "EventsMarche - Classifications"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 52, "external": true, "tree_label": "Feratel - CreativeCommons"}, "feratel_facilities_events": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Events", "sorting": 53, "external": true, "tree_label": "Feratel - Merkmale - Events"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 37, "external": true, "universal": true}, "open_destination_one_keywords": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "open.destination.one - Keywords", "sorting": 55, "external": true, "tree_label": "open.destination.one - Keywords"}}, "schema_type": "Event", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.781759	2020-10-29 13:34:01.785718	2020-10-29 13:34:01.785718	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
593bcdd9-1bfa-43f3-9ad1-901889b9bf94	\N	EventOverlay	{"api": {}, "name": "EventOverlay", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Inhalt URL", "sorting": 7, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 14, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 6, "template_name": "Bild"}, "end_date": {"ui": {"show": {"content_area": "none"}}, "type": "computed", "label": "Endzeitpunkt", "compute": {"type": "datetime", "method": "end_date", "module": "Utility::Compute::Schedule", "parameters": {"0": "event_schedule"}}, "sorting": 4, "storage_location": "column"}, "schedule": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "eventSchedule"}, "type": "embedded", "label": "Event-Schedule", "sorting": 13, "translated": true, "template_name": "EventSchedule"}, "start_date": {"ui": {"show": {"content_area": "none"}}, "type": "computed", "label": "Startzeitpunkt", "compute": {"type": "datetime", "method": "start_date", "module": "Utility::Compute::Schedule", "parameters": {"0": "event_schedule"}}, "sorting": 3, "storage_location": "column"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 5, "storage_location": "column"}, "event_status": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"disabled": true}, "type": "classification", "label": "Veranstaltungsstatus", "sorting": 11, "tree_label": "Veranstaltungsstatus"}, "event_schedule": {"api": {"v4": {"disabled": false}, "disabled": true}, "type": "schedule", "label": "Termine", "sorting": 12}, "content_location": {"api": {"name": "location"}, "type": "linked", "label": "Veranstaltungsort", "sorting": 8, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "virtual_location": {"api": {"disabled": true}, "type": "embedded", "label": "Virtueller Veranstaltungsort", "sorting": 9, "template_name": "VirtualLocation"}, "event_attendance_mode": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"disabled": true}, "type": "classification", "label": "Veranstaltungsteilnahmemodus", "sorting": 10, "tree_label": "Veranstaltungsteilnahmemodus"}}, "schema_type": "Event", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.801124	2020-10-29 13:34:01.80258	2020-10-29 13:34:01.80258	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
75f1286c-e6ca-4602-a3ff-9a5683715424	\N	EventSchedule	{"api": {"type": "Schedule"}, "name": "EventSchedule", "type": "object", "boost": 100.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "by_month": {"type": "number", "label": "Monat", "sorting": 5, "storage_location": "value"}, "event_date": {"ui": {"edit": {"type": "daterange"}}, "api": {"transformation": {"method": "unwrap"}}, "type": "object", "label": "Datum", "sorting": 2, "properties": {"end_date": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "column"}, "start_date": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Von", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "column"}}, "validations": {"daterange": {"to": "end_date", "from": "start_date"}}, "storage_location": "value"}, "event_time": {"api": {"transformation": {"method": "unwrap"}}, "type": "object", "label": "Uhrzeit", "sorting": 3, "properties": {"end_time": {"ui": {"edit": {"options": {"placeholder": "hh:mm"}}}, "type": "string", "label": "Ende", "sorting": 2, "validations": {"pattern": "(^$|^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$|^24:00(:00)?$)"}, "storage_location": "value"}, "start_time": {"ui": {"edit": {"options": {"placeholder": "hh:mm"}}}, "type": "string", "label": "Beginn", "sorting": 1, "validations": {"pattern": "(^$|^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$|^24:00(:00)?$)"}, "storage_location": "value"}}, "storage_location": "value"}, "day_of_week": {"api": {"name": "by_day"}, "type": "classification", "label": "Wochentag", "sorting": 4, "tree_label": "Wochentage"}, "by_month_day": {"type": "number", "label": "Tag im Monat", "sorting": 6, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 10, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 12, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 13, "storage_location": "column"}, "repeat_count": {"type": "number", "label": "Anzahl der Wiederholungen", "sorting": 7, "storage_location": "value"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 11, "storage_location": "value"}, "repeat_frequency": {"type": "string", "label": "Frequenz", "sorting": 8, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 9, "external": true, "universal": true}}, "schema_type": "Event", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.813386	2020-10-29 13:34:01.820735	2020-10-29 13:34:01.820735	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	embedded	\N
bea40a60-78d6-462d-a4db-be01f174c574	\N	Eventserie	{"api": {"type": "EventSeries"}, "name": "Eventserie", "type": "object", "boost": 100.0, "features": {"overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 3, "normalize": {"id": "eventname", "type": "eventname"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "image": {"type": "linked", "label": "Bilder", "sorting": 8, "template_name": "Bild"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 18, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 2, "validations": {"max": 1}, "template_name": "EventserieOverlay"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 17, "tree_label": "Inhaltstypen", "default_value": "Veranstaltungsserie"}, "organizer": {"type": "linked", "label": "Veranstalter", "sorting": 12, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "LocalBusiness"], "treeLabel": "Inhaltstypen"}}]}, "performer": {"type": "linked", "label": "Ausführende Person/Organisation", "sorting": 11, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "sub_event": {"type": "linked", "label": "Veranstaltungen", "sorting": 9, "inverse_of": "super_event", "template_name": "Event", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 7, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 25, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 27, "storage_location": "value"}, "event_status": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"v4": {"partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Veranstaltungsstatus", "sorting": 15, "tree_label": "Veranstaltungsstatus"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 28, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 26, "storage_location": "value"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 22, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 21, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 4, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 20, "external": true, "storage_location": "value"}, "content_location": {"api": {"name": "location"}, "type": "linked", "label": "Veranstaltungsort", "sorting": 10, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 19, "external": true, "storage_location": "value"}, "potential_action": {"api": {"type": "ViewAction", "partial": "action", "transformation": {"name": "potentialAction", "method": "append"}}, "type": "string", "label": "Link mit weiterführenden Infos", "sorting": 16, "storage_location": "translated_value"}, "virtual_location": {"api": {"v4": {"disabled": false, "transformation": {"name": "location", "method": "append"}}, "disabled": true}, "type": "embedded", "label": "Virtueller Veranstaltungsort", "sorting": 13, "template_name": "VirtualLocation"}, "event_attendance_mode": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"v4": {"partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Veranstaltungsteilnahmemodus", "sorting": 14, "tree_label": "Veranstaltungsteilnahmemodus"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 23, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 24, "external": true, "universal": true}}, "schema_type": "Event", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.834306	2020-10-29 13:34:01.836511	2020-10-29 13:34:01.836511	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
48c72098-be3e-4779-977d-d9901ff4cbf9	{"license": null, "date_created": null, "date_deleted": null, "date_modified": null, "attribution_url": null, "validity_period": {"valid_from": null, "valid_until": null}, "attribution_name": null, "more_permissions": null, "release_status_comment": ""}	Strukturierter Artikel	{"api": {"type": "Article"}, "name": "Strukturierter Artikel", "type": "object", "boost": 100.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "releasable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Link", "search": true, "sorting": 19, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 4, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 8, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Fließtext", "search": true, "sorting": 15, "storage_location": "translated_value"}, "about": {"type": "linked", "label": "Hauptthema", "sorting": 12, "inverse_of": "subject_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie", "Unterkunft"], "treeLabel": "Inhaltstypen"}}]}, "image": {"type": "linked", "label": "Bilder", "sorting": 16, "template_name": "Bild"}, "video": {"type": "linked", "label": "Videos", "sorting": 17, "template_name": "Video"}, "author": {"type": "linked", "label": "Autor", "sorting": 14, "validations": {"max": 1}, "template_name": "Person"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "headline": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Headline", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 6, "storage_location": "translated_value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 20, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 23, "tree_label": "Inhaltstypen", "default_value": "Strukturierter Artikel"}, "link_name": {"api": {"v4": {"name": "linkName", "type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "name": "name"}, "type": "string", "label": "Linktitel", "search": true, "sorting": 11, "storage_location": "translated_value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 13, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 25, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 27, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 28, "storage_location": "column"}, "content_block": {"type": "embedded", "label": "Inhaltsblock", "sorting": 21, "template_name": "Inhaltsblock"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 26, "storage_location": "value"}, "internal_name": {"api": {"disabled": true}, "type": "string", "label": "Arbeitstitel", "search": true, "sorting": 5, "storage_location": "column"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 9, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 33, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 32, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 7, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 18, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 22, "translated": true, "template_name": "Action"}, "release_status_id": {"ui": {"edit": {"options": {"multiple": false, "data-allow-clear": false}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "classification", "label": "Status", "sorting": 2, "tree_label": "Release-Stati", "default_value": "freigegeben"}, "alternative_headline": {"type": "string", "label": "Unterüberschrift", "search": true, "sorting": 10, "storage_location": "translated_value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 34, "tree_label": "Lizenzen"}, "release_status_comment": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "none"}}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "string", "label": "Kommentar", "sorting": 3, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 24, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	f		\N	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	e123d2d0-a678-4a95-b447-be62ca039ddf	\N	\N	2020-10-29 13:35:54.703551	2020-10-29 13:36:00.657695	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
9aa9d00e-255b-4967-aa1a-1eff4483745f	\N	EventserieOverlay	{"api": {}, "name": "EventserieOverlay", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 9, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 4, "template_name": "Bild"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 3, "storage_location": "column"}, "event_status": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"disabled": true}, "type": "classification", "label": "Veranstaltungsstatus", "sorting": 8, "tree_label": "Veranstaltungsstatus"}, "content_location": {"api": {"name": "location"}, "type": "linked", "label": "Veranstaltungsort", "sorting": 5, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "virtual_location": {"api": {"disabled": true}, "type": "embedded", "label": "Virtueller Veranstaltungsort", "sorting": 6, "template_name": "VirtualLocation"}, "event_attendance_mode": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"disabled": true}, "type": "classification", "label": "Veranstaltungsteilnahmemodus", "sorting": 7, "tree_label": "Veranstaltungsteilnahmemodus"}}, "schema_type": "Event", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.847175	2020-10-29 13:34:01.848614	2020-10-29 13:34:01.848614	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
82a97879-b276-4af6-9ec8-502ce198e1dd	\N	SubEvent	{"api": {}, "name": "SubEvent", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Inhalt URL", "sorting": 6, "external": true, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 8, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 5, "template_name": "Bild"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 4, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 10, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 12, "storage_location": "value"}, "event_period": {"ui": {"edit": {"type": "daterange"}}, "api": {"transformation": {"method": "unwrap"}}, "type": "object", "label": "Veranstaltungszeitraum", "sorting": 3, "properties": {"end_date": {"ui": {"edit": {"type": "datetime", "options": {"placeholder": "tt.mm.jjjj --:--", "data-validate": "daterange"}}}, "type": "datetime", "label": "Endzeitpunkt", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "column"}, "start_date": {"ui": {"edit": {"type": "datetime", "options": {"placeholder": "tt.mm.jjjj --:--", "data-validate": "daterange"}}}, "type": "datetime", "label": "Startzeitpunkt", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "column"}}, "validations": {"daterange": {"to": "end_date", "from": "start_date"}}, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 13, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 11, "storage_location": "value"}, "content_location": {"api": {"name": "location"}, "type": "linked", "label": "Veranstaltungsort", "sorting": 7, "validations": {"max": 1}, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 9, "external": true, "universal": true}}, "schema_type": "Event", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.857729	2020-10-29 13:34:01.859135	2020-10-29 13:34:01.859135	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
33c27a7d-7096-4615-95ba-f4f37b4ec2ab	\N	Bild	{"api": {"type": "ImageObject"}, "name": "Bild", "type": "object", "boost": 10.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "asset": {"web": ["png", "jpeg"], "original": ["png", "jpeg"]}, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"ui": {"edit": {"disabled": true}}, "api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Inhalt URL", "sorting": 12, "validations": {"format": "url"}, "storage_location": "value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true, "partial": "media_title"}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "asset": {"api": {"disabled": true}, "type": "asset", "label": "Datei", "sorting": 6, "asset_type": "image"}, "width": {"ui": {"show": {"options": {"data-unit": "px"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "E37", "unit_text": "pixel", "transformation": {"name": "width", "method": "nest"}}, "type": "computed", "label": "Breite", "compute": {"type": "number", "method": "width", "module": "Utility::Compute::Image", "parameters": {"0": "asset"}}, "sorting": 13, "advanced_search": true, "storage_location": "value"}, "author": {"type": "linked", "label": "Fotograf", "sorting": 18, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "height": {"ui": {"show": {"options": {"data-unit": "px"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "E37", "unit_text": "pixel", "transformation": {"name": "height", "method": "nest"}}, "type": "computed", "label": "Höhe", "compute": {"type": "number", "method": "height", "module": "Utility::Compute::Image", "parameters": {"0": "asset"}}, "sorting": 14, "advanced_search": true, "storage_location": "value"}, "caption": {"type": "string", "label": "Bildunterschrift", "search": true, "sorting": 8, "storage_location": "translated_value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 39, "external": true, "storage_location": "value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 22, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 33, "tree_label": "Inhaltstypen", "default_value": "Bild"}, "content_url": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Bild URL", "compute": {"type": "string", "method": "content_url", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 10, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Beschreibung (ALT-Label)", "search": true, "sorting": 9, "storage_location": "column"}, "file_format": {"type": "computed", "label": "Dateiformat", "compute": {"type": "string", "method": "file_format", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 16, "storage_location": "value"}, "upload_date": {"ui": {"edit": {"type": "date", "options": {"class": "daterange", "placeholder": "tt.mm.jjjj"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Hochgeladen am", "sorting": 17, "default_value": {"method": "beginning_of_day", "module": "DataCycleCore::Utility::DefaultValue::Date"}, "advanced_search": true, "storage_location": "value"}, "content_size": {"type": "computed", "label": "Dateigröße", "compute": {"type": "number", "method": "file_size", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 15, "advanced_search": true, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 35, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 37, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 38, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 36, "storage_location": "value"}, "folders_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Folders", "sorting": 27, "external": true, "tree_label": "Celum - Folders"}, "thumbnail_url": {"ui": {"show": {"partial": "preview_image"}}, "api": {"minimal": true}, "type": "computed", "label": "Thumbnail URL", "compute": {"type": "string", "method": "thumbnail_url", "module": "Utility::Compute::Image", "parameters": {"0": "asset"}}, "sorting": 11, "storage_location": "value"}, "copyright_year": {"type": "number", "label": "Copyright - Jahr", "sorting": 20, "advanced_search": true, "storage_location": "value"}, "keywords_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Keywords", "sorting": 26, "external": true, "tree_label": "Celum - Keywords"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "status_eyebase": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Eyebase - Status", "sorting": 25, "external": true, "tree_label": "Eyebase - Status"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 43, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 42, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 3, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 41, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 21, "validations": {"max": 1}, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "copyright_holder": {"type": "linked", "label": "Rechteinhaber", "sorting": 19, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "keywords_eyebase": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Eyebase - Tags", "sorting": 24, "external": true, "tree_label": "Eyebase - Tags"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 40, "external": true, "storage_location": "value"}, "wikidata_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wikidata - Image Categories", "sorting": 31, "external": true, "tree_label": "Wikidata - Image Categories"}, "types_of_use_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Verwendungsart", "sorting": 29, "external": true, "tree_label": "Celum - Verwendungsart"}, "alternative_headline": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "Alt-Label", "search": true, "sorting": 7, "storage_location": "translated_value"}, "hrs_image_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS - Image-Categories", "sorting": 30, "external": true, "tree_label": "HRS - Image-Categories"}, "keywords_medienarchive": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "MediaArchive - Tags", "sorting": 23, "external": true, "tree_label": "MediaArchive - Tags"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 44, "tree_label": "Lizenzen"}, "asset_collections_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Asset Collection", "sorting": 28, "external": true, "tree_label": "Celum - Asset Collections"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 34, "external": true, "universal": true}, "wikidata_license_classification": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wikidata - Lizenzen", "sorting": 32, "external": true, "tree_label": "Wikidata - Lizenzen"}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.878062	2020-10-29 13:34:01.881139	2020-10-29 13:34:01.881139	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
0df17d33-7d85-4d7e-8752-927397a0e01d	\N	Video	{"api": {"type": "VideoObject"}, "name": "Video", "type": "object", "boost": 10.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "asset": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"ui": {"edit": {"disabled": true}}, "api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Inhalt URL", "sorting": 11, "validations": {"format": "url"}, "storage_location": "value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true, "partial": "media_title"}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "asset": {"api": {"disabled": true}, "type": "asset", "label": "Datei", "sorting": 6, "asset_type": "video"}, "width": {"ui": {"show": {"options": {"data-unit": "px"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "E37", "unit_text": "pixel", "transformation": {"name": "width", "method": "nest"}}, "type": "computed", "label": "Breite", "compute": {"type": "number", "method": "width", "module": "Utility::Compute::Video", "parameters": {"0": "asset"}}, "sorting": 12, "advanced_search": true, "storage_location": "value"}, "height": {"ui": {"show": {"options": {"data-unit": "px"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "E37", "unit_text": "pixel", "transformation": {"name": "height", "method": "nest"}}, "type": "computed", "label": "Höhe", "compute": {"type": "number", "method": "height", "module": "Utility::Compute::Video", "parameters": {"0": "asset"}}, "sorting": 13, "advanced_search": true, "storage_location": "value"}, "caption": {"type": "string", "label": "Alt-Label", "search": true, "sorting": 7, "storage_location": "translated_value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 41, "external": true, "storage_location": "value"}, "director": {"type": "linked", "label": "Regie", "sorting": 21, "template_name": "Person"}, "duration": {"ui": {"show": {"options": {"data-unit": "sec"}}}, "api": {"format": {"append": "S", "prepend": "PT"}, "partial": "duration"}, "type": "computed", "label": "Dauer", "compute": {"type": "number", "method": "duration", "module": "Utility::Compute::Video", "parameters": {"0": "asset"}}, "sorting": 16, "advanced_search": true, "storage_location": "value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 26, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 35, "tree_label": "Inhaltstypen", "default_value": "Video"}, "content_url": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Video URL", "compute": {"type": "string", "method": "content_url", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 9, "storage_location": "value"}, "contributor": {"type": "linked", "label": "Kamera", "sorting": 22, "template_name": "Person"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Teasertext", "search": true, "sorting": 8, "storage_location": "column"}, "file_format": {"type": "computed", "label": "Dateiformat", "compute": {"type": "string", "method": "file_format", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 15, "storage_location": "value"}, "upload_date": {"ui": {"edit": {"type": "date", "options": {"class": "daterange", "placeholder": "tt.mm.jjjj"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Hochgeladen am", "sorting": 19, "default_value": {"method": "beginning_of_day", "module": "DataCycleCore::Utility::DefaultValue::Date"}, "advanced_search": true, "storage_location": "value"}, "youtube_url": {"api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}}, "type": "string", "label": "YouTube URL", "sorting": 20, "validations": {"format": "url"}, "storage_location": "value"}, "content_size": {"type": "computed", "label": "Dateigröße", "compute": {"type": "number", "method": "file_size", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 14, "advanced_search": true, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 37, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 39, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 40, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 38, "storage_location": "value"}, "folders_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Folders", "sorting": 31, "external": true, "tree_label": "Celum - Folders"}, "thumbnail_url": {"ui": {"show": {"partial": "preview_image"}}, "api": {"minimal": true}, "type": "computed", "label": "Teaserbild", "compute": {"type": "string", "method": "thumbnail_url", "module": "Utility::Compute::Video", "parameters": {"0": "asset"}}, "sorting": 10, "storage_location": "value"}, "video_quality": {"type": "computed", "label": "Qualität", "compute": {"type": "string", "method": "quality", "module": "Utility::Compute::Video", "parameters": {"0": "asset"}}, "sorting": 18, "storage_location": "value"}, "copyright_year": {"type": "number", "label": "Copyright - Jahr", "sorting": 24, "advanced_search": true, "storage_location": "value"}, "keywords_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Keywords", "sorting": 30, "external": true, "tree_label": "Celum - Keywords"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "status_eyebase": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Eyebase - Status", "sorting": 29, "external": true, "tree_label": "Eyebase - Status"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 45, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 44, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 3, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 43, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 25, "validations": {"max": 1}, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "copyright_holder": {"type": "linked", "label": "Rechteinhaber", "sorting": 23, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "keywords_eyebase": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Eyebase - Tags", "sorting": 28, "external": true, "tree_label": "Eyebase - Tags"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 42, "external": true, "storage_location": "value"}, "video_frame_size": {"type": "computed", "label": "Auslösung", "compute": {"type": "string", "method": "frame_size", "module": "Utility::Compute::Video", "parameters": {"0": "asset"}}, "sorting": 17, "storage_location": "value"}, "types_of_use_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Verwendungsart", "sorting": 33, "external": true, "tree_label": "Celum - Verwendungsart"}, "hrs_image_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS - Image-Categories", "sorting": 34, "external": true, "tree_label": "HRS - Image-Categories"}, "keywords_medienarchive": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "MediaArchive - Tags", "sorting": 27, "external": true, "tree_label": "MediaArchive - Tags"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 46, "tree_label": "Lizenzen"}, "asset_collections_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Asset Collection", "sorting": 32, "external": true, "tree_label": "Celum - Asset Collections"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 36, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.903787	2020-10-29 13:34:01.906953	2020-10-29 13:34:01.906953	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
49d3be1e-ff2d-4cfe-85ed-818a9a501061	\N	Datei	{"api": {"type": "MediaObject"}, "name": "Datei", "type": "object", "boost": 10.0, "features": {"download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "asset": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true, "partial": "media_title"}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "asset": {"api": {"disabled": true}, "type": "asset", "label": "Datei", "sorting": 6, "asset_type": "data_cycle_file"}, "author": {"type": "linked", "label": "Fotograf", "sorting": 12, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 23, "external": true, "storage_location": "value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 16, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 17, "tree_label": "Inhaltstypen", "default_value": "Datei"}, "content_url": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Datei URL", "compute": {"type": "string", "method": "content_url", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 8, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 7, "storage_location": "column"}, "file_format": {"type": "computed", "label": "Dateiformat", "compute": {"type": "string", "method": "file_format", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 10, "storage_location": "value"}, "upload_date": {"ui": {"edit": {"type": "date", "options": {"class": "daterange", "placeholder": "tt.mm.jjjj"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Hochgeladen am", "sorting": 11, "default_value": {"method": "beginning_of_day", "module": "DataCycleCore::Utility::DefaultValue::Date"}, "advanced_search": true, "storage_location": "value"}, "content_size": {"type": "computed", "label": "Dateigröße", "compute": {"type": "number", "method": "file_size", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 9, "advanced_search": true, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 19, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 21, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 22, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 20, "storage_location": "value"}, "copyright_year": {"type": "number", "label": "Copyright - Jahr", "sorting": 14, "advanced_search": true, "storage_location": "value"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 27, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 26, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 3, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 25, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 15, "validations": {"max": 1}, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "copyright_holder": {"type": "linked", "label": "Rechteinhaber", "sorting": 13, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 24, "external": true, "storage_location": "value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 28, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 18, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.924452	2020-10-29 13:34:01.926639	2020-10-29 13:34:01.926639	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
21bc6f66-42cb-403b-b5db-b6f34a7dc32e	\N	Audio	{"api": {"type": "AudioObject"}, "name": "Audio", "type": "object", "boost": 10.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "asset": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Inhalt URL", "sorting": 9, "validations": {"format": "url"}, "storage_location": "value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true, "partial": "media_title"}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "asset": {"api": {"disabled": true}, "type": "asset", "label": "Datei", "sorting": 6, "asset_type": "audio"}, "author": {"type": "linked", "label": "Fotograf", "sorting": 14, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 33, "external": true, "storage_location": "value"}, "duration": {"ui": {"show": {"options": {"data-unit": "sec"}}}, "api": {"format": {"append": "S", "prepend": "PT"}, "partial": "duration"}, "type": "computed", "label": "Dauer", "compute": {"type": "number", "method": "duration", "module": "Utility::Compute::Audio", "parameters": {"0": "asset"}}, "sorting": 12, "advanced_search": true, "storage_location": "value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 18, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 27, "tree_label": "Inhaltstypen", "default_value": "Audio"}, "content_url": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Audio URL", "compute": {"type": "string", "method": "content_url", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 8, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 7, "storage_location": "column"}, "file_format": {"type": "computed", "label": "Dateiformat", "compute": {"type": "string", "method": "file_format", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 11, "storage_location": "value"}, "upload_date": {"ui": {"edit": {"type": "date", "options": {"class": "daterange", "placeholder": "tt.mm.jjjj"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Hochgeladen am", "sorting": 13, "default_value": {"method": "beginning_of_day", "module": "DataCycleCore::Utility::DefaultValue::Date"}, "advanced_search": true, "storage_location": "value"}, "content_size": {"type": "computed", "label": "Dateigröße", "compute": {"type": "number", "method": "file_size", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 10, "advanced_search": true, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 29, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 31, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 32, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 30, "storage_location": "value"}, "folders_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Folders", "sorting": 23, "external": true, "tree_label": "Celum - Folders"}, "copyright_year": {"type": "number", "label": "Copyright - Jahr", "sorting": 16, "advanced_search": true, "storage_location": "value"}, "keywords_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Keywords", "sorting": 22, "external": true, "tree_label": "Celum - Keywords"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "status_eyebase": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Eyebase - Status", "sorting": 21, "external": true, "tree_label": "Eyebase - Status"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 37, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 36, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 3, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 35, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 17, "validations": {"max": 1}, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "copyright_holder": {"type": "linked", "label": "Rechteinhaber", "sorting": 15, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "keywords_eyebase": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Eyebase - Tags", "sorting": 20, "external": true, "tree_label": "Eyebase - Tags"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 34, "external": true, "storage_location": "value"}, "types_of_use_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Verwendungsart", "sorting": 25, "external": true, "tree_label": "Celum - Verwendungsart"}, "hrs_image_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS - Image-Categories", "sorting": 26, "external": true, "tree_label": "HRS - Image-Categories"}, "keywords_medienarchive": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "MediaArchive - Tags", "sorting": 19, "external": true, "tree_label": "MediaArchive - Tags"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 38, "tree_label": "Lizenzen"}, "asset_collections_celum": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Celum - Asset Collection", "sorting": 24, "external": true, "tree_label": "Celum - Asset Collections"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 28, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.945138	2020-10-29 13:34:01.948139	2020-10-29 13:34:01.948139	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
54c7f64f-3b45-4f6d-984d-17774092a55c	\N	PDF	{"api": {"type": "MediaObject"}, "name": "PDF", "type": "object", "boost": 10.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "asset": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true, "partial": "media_title"}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "text": {"ui": {"show": {"disabled": true}}, "api": {"disabled": true}, "type": "computed", "label": "Inhalt", "search": true, "compute": {"type": "string", "method": "extract_content", "module": "Utility::Compute::Pdf", "parameters": {"0": "asset"}}, "sorting": 8, "storage_location": "value"}, "asset": {"api": {"disabled": true}, "type": "asset", "label": "Datei", "sorting": 6, "asset_type": "pdf"}, "width": {"ui": {"show": {"options": {"data-unit": "px"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "E37", "unit_text": "pixel", "transformation": {"name": "width", "method": "nest"}}, "type": "computed", "label": "Breite", "compute": {"type": "number", "method": "width", "module": "Utility::Compute::Pdf", "parameters": {"0": "asset"}}, "sorting": 11, "advanced_search": true, "storage_location": "value"}, "author": {"type": "linked", "label": "Fotograf", "sorting": 16, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "height": {"ui": {"show": {"options": {"data-unit": "px"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "E37", "unit_text": "pixel", "transformation": {"name": "height", "method": "nest"}}, "type": "computed", "label": "Höhe", "compute": {"type": "number", "method": "height", "module": "Utility::Compute::Pdf", "parameters": {"0": "asset"}}, "sorting": 12, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 27, "external": true, "storage_location": "value"}, "keywords": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Keywords", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "tags"}}, "sorting": 20, "storage_location": "translated_value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 21, "tree_label": "Inhaltstypen", "default_value": "PDF"}, "content_url": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "PDF URL", "compute": {"type": "string", "method": "content_url", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 9, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 7, "storage_location": "column"}, "file_format": {"type": "computed", "label": "Dateiformat", "compute": {"type": "string", "method": "file_format", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 14, "storage_location": "value"}, "upload_date": {"ui": {"edit": {"type": "date", "options": {"class": "daterange", "placeholder": "tt.mm.jjjj"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Hochgeladen am", "sorting": 15, "default_value": {"method": "beginning_of_day", "module": "DataCycleCore::Utility::DefaultValue::Date"}, "advanced_search": true, "storage_location": "value"}, "content_size": {"type": "computed", "label": "Dateigröße", "compute": {"type": "number", "method": "file_size", "module": "Utility::Compute::Asset", "parameters": {"0": "asset"}}, "sorting": 13, "advanced_search": true, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 23, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 25, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 26, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 24, "storage_location": "value"}, "thumbnail_url": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Thumbnail URL", "compute": {"type": "string", "method": "thumbnail_url", "module": "Utility::Compute::Pdf", "parameters": {"0": "asset"}}, "sorting": 10, "storage_location": "value"}, "copyright_year": {"type": "number", "label": "Copyright - Jahr", "sorting": 18, "advanced_search": true, "storage_location": "value"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 31, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 3, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "content_location": {"type": "linked", "label": "Ort", "sorting": 19, "validations": {"max": 1}, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "copyright_holder": {"type": "linked", "label": "Rechteinhaber", "sorting": 17, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 28, "external": true, "storage_location": "value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 32, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 22, "external": true, "universal": true}}, "schema_type": "CreativeWork", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.971958	2020-10-29 13:34:01.974488	2020-10-29 13:34:01.974488	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
953f6f7c-d492-456a-8db8-345eb9b53b60	\N	Organization	{"api": {}, "name": "Organization", "type": "object", "boost": 1.0, "features": {"download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Firmenname", "search": true, "sorting": 2, "normalize": {"id": "company", "type": "company"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "image": {"type": "linked", "label": "Bilder", "sorting": 17, "template_name": "Bild"}, "member": {"type": "linked", "label": "Mitglieder", "sorting": 18, "inverse_of": "member_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}], "link_direction": "inverse"}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 12, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 24, "external": true, "storage_location": "value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 23, "tree_label": "Inhaltstypen", "default_value": "Organisation"}, "legal_name": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "Legal Name", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 3, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 22, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Text", "search": true, "sorting": 16, "storage_location": "column"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 15, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 13, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 31, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 33, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 34, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 21, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 20, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 32, "storage_location": "value"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 11, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 28, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 27, "external": true, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 26, "external": true, "storage_location": "value"}, "content_location": {"api": {"name": "location"}, "type": "linked", "label": "Standort", "sorting": 19, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 14, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 25, "external": true, "storage_location": "value"}, "feratel_identity_role": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel Identity Server Role", "sorting": 9, "tree_label": "Feratel Identity Server Roles"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 29, "tree_label": "Lizenzen"}, "feratel_identity_claims": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel Identity Server Claims", "sorting": 6, "tree_label": "Feratel Identity Server Claims"}, "feratel_identity_realms": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel Identity Server Realms", "sorting": 7, "tree_label": "Feratel Identity Server Realms"}, "feratel_identity_db_code": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel Identity Server dbCode", "sorting": 8, "tree_label": "Feratel Identity Server dbCodes"}, "feratel_identity_keywords": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel Identity Server Keywords", "sorting": 5, "tree_label": "Feratel Identity Server Keywords"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 30, "external": true, "universal": true}, "feratel_identity_user_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel Identity Server userType", "sorting": 10, "tree_label": "Feratel Identity Server userTypes"}}, "schema_type": "Organization", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:01.99256	2020-10-29 13:34:01.995303	2020-10-29 13:34:01.995303	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	entity	\N
2383a086-156d-47dd-9044-b35668ac5c84	\N	Person	{"api": {}, "name": "Person", "type": "object", "boost": 1.0, "features": {"overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Name", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "given_name", "type": "content"}, "1": " ", "2": {"name": "family_name", "type": "content"}}}, "sorting": 4, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 7, "tree_label": "Tags"}, "image": {"type": "linked", "label": "Bilder", "sorting": 16, "template_name": "Bild"}, "gender": {"ui": {"show": {"content_area": "header"}}, "api": {"type": "GenderType", "partial": "enumeration"}, "type": "classification", "label": "Geschlecht", "sorting": 17, "tree_label": "Geschlecht"}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 11, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 25, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 6, "validations": {"max": 1}, "template_name": "PersonOverlay"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 24, "tree_label": "Inhaltstypen", "default_value": "Person"}, "job_title": {"type": "string", "label": "Position / Berufsbezeichnung", "search": true, "sorting": 5, "storage_location": "translated_value"}, "member_of": {"type": "linked", "label": "Organisation", "sorting": 20, "inverse_of": "member", "template_name": "Organization"}, "gender_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "gender", "partial": "gender"}, "type": "computed", "label": "Geschlecht", "compute": {"type": "string", "method": "description", "module": "Utility::Compute::Classification", "parameters": {"0": "gender"}}, "sorting": 19, "storage_location": "value"}, "given_name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Vorname", "search": true, "sorting": 2, "normalize": {"id": "forename", "type": "forename"}, "storage_location": "column"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 23, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Text", "search": true, "sorting": 15, "storage_location": "column"}, "family_name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Nachname", "search": true, "sorting": 3, "normalize": {"id": "surname", "type": "surname"}, "validations": {"required": true}, "storage_location": "column"}, "nationality": {"ui": {"show": {"content_area": "header"}}, "api": {"type": "Country", "partial": "enumeration"}, "type": "classification", "label": "Nationalität", "sorting": 18, "tree_label": "Länder"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 14, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 12, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 32, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 34, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 35, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 22, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 21, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 33, "storage_location": "value"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 8, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 29, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 28, "external": true, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 27, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 13, "storage_location": "value"}, "honorific_prefix": {"type": "string", "label": "Anrede / Titel", "sorting": 9, "normalize": {"id": "degree", "type": "degree"}, "storage_location": "translated_value"}, "honorific_suffix": {"type": "string", "label": "Titel nachgestellt", "sorting": 10, "storage_location": "translated_value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 26, "external": true, "storage_location": "value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 30, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 31, "external": true, "universal": true}}, "schema_type": "Person", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.01475	2020-10-29 13:34:02.017415	2020-10-29 13:34:02.017415	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	entity	\N
3e2b57d7-6f58-4239-a7c8-5b058e732652	\N	PersonOverlay	{"api": {}, "name": "PersonOverlay", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"disabled": true}}, "type": "computed", "label": "Name", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "given_name", "type": "content"}, "1": " ", "2": {"name": "family_name", "type": "content"}}}, "sorting": 4, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 10, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 9, "template_name": "Bild"}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 5, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "given_name": {"type": "string", "label": "Vorname", "search": true, "sorting": 2, "normalize": {"id": "forename", "type": "forename"}, "storage_location": "column"}, "family_name": {"type": "string", "label": "Nachname", "search": true, "sorting": 3, "normalize": {"id": "surname", "type": "surname"}, "storage_location": "column"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 8, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 6, "tree_label": "Ländercodes"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 7, "storage_location": "value"}}, "schema_type": "Person", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.031204	2020-10-29 13:34:02.03287	2020-10-29 13:34:02.03287	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
59b193d2-37b3-4833-a154-cd55c63b3a19	\N	Zimmer	{"api": {"type": ["Accommodation", "Product"]}, "name": "Zimmer", "type": "object", "boost": 10.0, "features": {"download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "image": {"type": "linked", "label": "Bilder", "sorting": 8, "template_name": "Bild"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 10, "external": true, "storage_location": "value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 9, "tree_label": "Inhaltstypen", "default_value": "Zimmer"}, "floor_size": {"type": "number", "label": "Größe (m²)", "sorting": 7, "advanced_search": true, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 3, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 17, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 19, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 20, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 18, "storage_location": "value"}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 4, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 14, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 13, "external": true, "storage_location": "value"}, "number_of_rooms": {"type": "number", "label": "Räume", "sorting": 6, "advanced_search": true, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 12, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 11, "external": true, "storage_location": "value"}, "feratel_product_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Produktarten", "sorting": 5, "external": true, "tree_label": "Feratel - Produktarten", "not_translated": true}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 15, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 16, "external": true, "universal": true}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.043674	2020-10-29 13:34:02.045267	2020-10-29 13:34:02.045267	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
f74938bc-ccbb-4184-bede-2b78c7059d88	\N	Gastronomischer Betrieb	{"api": {"type": "FoodEstablishment"}, "name": "Gastronomischer Betrieb", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 21, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 18, "storage_location": "translated_value"}, "tour": {"api": {"disabled": true}, "type": "linked", "label": "Touren", "sorting": 31, "inverse_of": "poi", "template_name": "Tour", "link_direction": "inverse"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 20, "template_name": "Bild"}, "price": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Preis", "sorting": 27, "external": true, "storage_location": "translated_value"}, "stars": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Sterne", "sorting": 51, "external": true, "tree_label": "Feratel - Sterne"}, "author": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Autor", "sorting": 26, "external": true, "storage_location": "translated_value"}, "source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Quelle", "sorting": 37, "external": true, "tree_label": "OutdoorActive - Quellen", "not_translated": true}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 9, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 60, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "parking": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Parkmöglichkeit", "search": true, "sorting": 29, "external": true, "storage_location": "translated_value"}, "regions": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Regionen", "sorting": 36, "external": true, "tree_label": "OutdoorActive - Regionen"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 13, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 15, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 41, "tree_label": "Inhaltstypen", "default_value": "Gastronomischer Betrieb"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 14, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 12, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "directions": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Anfahrtsbeschreibung", "search": true, "sorting": 28, "external": true, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 22, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 17, "storage_location": "column"}, "price_range": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Preis-Info", "search": true, "sorting": 25, "storage_location": "translated_value"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 16, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 10, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 67, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 69, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 70, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 24, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 23, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 68, "storage_location": "value"}, "feratel_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturtypen", "sorting": 48, "external": true, "tree_label": "Feratel - Infrastrukturtypen"}, "frontend_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Frontend-Typ", "sorting": 32, "external": true, "tree_label": "OutdoorActive - FrontendTypes", "not_translated": true}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 19, "validations": {"max": 1}, "template_name": "Bild"}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 52, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 53, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "feratel_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturklassifizierungen", "sorting": 49, "external": true, "tree_label": "Feratel - Infrastrukturklassifizierungen"}, "gourmet_rating": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Gourmet-Bewertung", "sorting": 6, "tree_label": "Gourmet-Bewertungen"}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 42, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "poi_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 34, "external": true, "tree_label": "OutdoorActive - POI-Kategorien"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 64, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 63, "external": true, "storage_location": "value"}, "hours_available": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Service-Zeiten", "sorting": 30, "external": true, "storage_location": "translated_value"}, "tour_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 33, "external": true, "tree_label": "OutdoorActive - Touren-Kategorien"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 62, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 11, "storage_location": "value"}, "feratel_cps_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Typ", "sorting": 57, "external": true, "tree_label": "Feratel CPS - Typen"}, "marketing_groups": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Marketinggruppen", "sorting": 54, "external": true, "tree_label": "Feratel - Marketinggruppen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 61, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 40, "translated": true, "template_name": "Action"}, "wogehmahin_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Types", "sorting": 59, "external": true, "tree_label": "Wogehmahin - Types"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 50, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "wogehmahin_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Topics", "sorting": 58, "external": true, "tree_label": "Wogehmahin - Topics"}, "feratel_cps_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Status", "sorting": 56, "external": true, "tree_label": "Feratel CPS - Stati"}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 45, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "outdoor_active_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Tags", "sorting": 35, "external": true, "tree_label": "OutdoorActive - Tags", "not_translated": true}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 65, "tree_label": "Lizenzen"}, "feratel_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsklassifizierungen", "sorting": 44, "external": true, "tree_label": "Feratel - Unterkunftsklassifizierungen"}, "accommodation_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsarten", "sorting": 43, "external": true, "tree_label": "Feratel - Unterkunftsarten"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 55, "external": true, "tree_label": "Feratel - CreativeCommons"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 66, "external": true, "universal": true}, "dining_hours_specification": {"api": {"partial": "opening_hours_specification"}, "type": "embedded", "label": "Warme Küche", "sorting": 8, "translated": true, "template_name": "Öffnungszeit"}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 7, "translated": true, "template_name": "Öffnungszeit"}, "outdoor_active_system_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Kategorien", "global": true, "sorting": 38, "tree_label": "OutdoorActive - System - Kategorien"}, "feratel_facilities_accommodations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Unterkünfte", "sorting": 46, "external": true, "tree_label": "Feratel - Merkmale - Unterkünfte"}, "outdoor_active_system_source_keys": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Quellen", "global": true, "sorting": 39, "tree_label": "OutdoorActive - System - Quellen", "validations": {"max": 1}}, "feratel_facilities_additional_services": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Services", "sorting": 47, "external": true, "tree_label": "Feratel - Merkmale - Services"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.06863	2020-10-29 13:34:02.073395	2020-10-29 13:34:02.073395	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
0de6dbf7-a88d-40a6-bdc2-9ab55b0fa529	\N	Lift	{"api": {"type": ["TouristAttraction", "dcls:Lift"]}, "name": "Lift", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 19, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 16, "storage_location": "translated_value"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 18, "template_name": "Bild"}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 7, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 27, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 11, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 13, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 24, "tree_label": "Inhaltstypen", "default_value": "Lift"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 12, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 10, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 20, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 15, "storage_location": "column"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 14, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 8, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 34, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 36, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 37, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 22, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 21, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 35, "storage_location": "value"}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 17, "validations": {"max": 1}, "template_name": "Bild"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 31, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 9, "storage_location": "value"}, "feratel_cps_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Typ", "sorting": 26, "external": true, "tree_label": "Feratel CPS - Typen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 28, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 23, "translated": true, "template_name": "Action"}, "feratel_cps_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Status", "sorting": 25, "external": true, "tree_label": "Feratel CPS - Stati"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 32, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 33, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 6, "translated": true, "template_name": "Öffnungszeit"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.100931	2020-10-29 13:34:02.103834	2020-10-29 13:34:02.103834	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
89ed1043-4e2e-4690-97a0-7870ff51e65a	\N	LocalBusiness	{"api": {"type": "LocalBusiness"}, "name": "LocalBusiness", "type": "object", "boost": 10.0, "features": {"geocode": {"allowed": true}, "overlay": {"allowed": true}, "download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"gpx": true, "xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "logo": {"api": {"minimal": true}, "type": "linked", "label": "Logo", "sorting": 20, "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 17, "storage_location": "translated_value"}, "tour": {"api": {"disabled": true}, "type": "linked", "label": "Touren", "sorting": 32, "inverse_of": "poi", "template_name": "Tour", "link_direction": "inverse"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 19, "template_name": "Bild"}, "price": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Preis", "sorting": 28, "external": true, "storage_location": "translated_value"}, "stars": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Sterne", "sorting": 52, "external": true, "tree_label": "Feratel - Sterne"}, "author": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Autor", "sorting": 27, "external": true, "storage_location": "translated_value"}, "source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Quelle", "sorting": 38, "external": true, "tree_label": "OutdoorActive - Quellen", "not_translated": true}, "address": {"api": {"type": "PostalAddress"}, "xml": {"type": "PostalAddress"}, "type": "object", "label": "Adresse", "sorting": 8, "properties": {"postal_code": {"type": "string", "label": "PLZ", "sorting": 2, "normalize": {"id": "zip", "type": "zip"}, "advanced_search": true, "storage_location": "value"}, "street_address": {"type": "string", "label": "Straße", "sorting": 1, "normalize": {"id": "street", "type": "street"}, "advanced_search": true, "storage_location": "value"}, "address_country": {"type": "string", "label": "Land", "sorting": 4, "normalize": {"id": "country", "type": "country"}, "advanced_search": true, "storage_location": "value"}, "address_locality": {"type": "string", "label": "Ort", "sorting": 3, "normalize": {"id": "city", "type": "city"}, "advanced_search": true, "storage_location": "value"}}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 61, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 3, "validations": {"max": 1}, "template_name": "PlaceOverlay"}, "parking": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Parkmöglichkeit", "search": true, "sorting": 30, "external": true, "storage_location": "translated_value"}, "regions": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Regionen", "sorting": 37, "external": true, "tree_label": "OutdoorActive - Regionen"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 12, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 14, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 42, "tree_label": "Inhaltstypen", "default_value": "LocalBusiness"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 13, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 11, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "directions": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Anfahrtsbeschreibung", "search": true, "sorting": 29, "external": true, "storage_location": "translated_value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 21, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 16, "storage_location": "column"}, "makes_offer": {"type": "embedded", "label": "Angebote", "sorting": 22, "translated": true, "template_name": "Angebot"}, "price_range": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Preis-Info", "search": true, "sorting": 25, "storage_location": "translated_value"}, "contact_info": {"api": {"transformation": {"name": "address", "method": "merge_object"}}, "type": "object", "label": "Kontakt", "sorting": 15, "properties": {"url": {"type": "string", "label": "Web", "sorting": 5, "storage_location": "translated_value"}, "name": {"api": {"v4": {"name": "name"}, "name": "contact_name"}, "type": "string", "label": "Ansprechpartner", "sorting": 1, "advanced_search": true, "storage_location": "translated_value"}, "email": {"type": "string", "label": "E-Mail", "sorting": 4, "normalize": {"id": "email", "type": "email"}, "advanced_search": true, "storage_location": "translated_value"}, "telephone": {"type": "string", "label": "Telefonnummer", "sorting": 2, "advanced_search": true, "storage_location": "translated_value"}, "fax_number": {"type": "string", "label": "Fax", "sorting": 3, "advanced_search": true, "storage_location": "translated_value"}}, "advanced_search": true, "storage_location": "translated_value"}, "country_code": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "addressCountry", "partial": "string", "transformation": {"name": "address", "method": "nest"}}, "partial": "country_code", "transformation": {"name": "address", "method": "nest"}}, "type": "classification", "label": "Ländercode", "sorting": 9, "tree_label": "Ländercodes"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 68, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 70, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 71, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 24, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 23, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 69, "storage_location": "value"}, "feratel_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturtypen", "sorting": 49, "external": true, "tree_label": "Feratel - Infrastrukturtypen"}, "frontend_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Frontend-Typ", "sorting": 33, "external": true, "tree_label": "OutdoorActive - FrontendTypes", "not_translated": true}, "primary_image": {"api": {"v4": {"name": "photo"}, "name": "image", "minimal": true}, "type": "linked", "label": "Hauptbild", "sorting": 18, "validations": {"max": 1}, "template_name": "Bild"}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 53, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 54, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "feratel_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Infrastrukturklassifizierungen", "sorting": 50, "external": true, "tree_label": "Feratel - Infrastrukturklassifizierungen"}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 43, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "poi_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 35, "external": true, "tree_label": "OutdoorActive - POI-Kategorien"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 65, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 64, "external": true, "storage_location": "value"}, "hours_available": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Service-Zeiten", "sorting": 31, "external": true, "storage_location": "translated_value"}, "tour_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Kategorie", "sorting": 34, "external": true, "tree_label": "OutdoorActive - Touren-Kategorien"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 63, "external": true, "storage_location": "value"}, "country_code_api": {"ui": {"show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "address_country", "transformation": {"name": "address", "method": "nest"}}, "type": "computed", "label": "Ländercode", "compute": {"type": "string", "method": "keywords", "module": "Utility::Compute::Classification", "parameters": {"0": "country_code"}}, "sorting": 10, "storage_location": "value"}, "feratel_cps_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Typ", "sorting": 58, "external": true, "tree_label": "Feratel CPS - Typen"}, "marketing_groups": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Marketinggruppen", "sorting": 55, "external": true, "tree_label": "Feratel - Marketinggruppen"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 62, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 41, "translated": true, "template_name": "Action"}, "wogehmahin_types": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Types", "sorting": 60, "external": true, "tree_label": "Wogehmahin - Types"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 51, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "wogehmahin_topics": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Wogehmahin - Topics", "sorting": 59, "external": true, "tree_label": "Wogehmahin - Topics"}, "feratel_cps_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel CPS - Status", "sorting": 57, "external": true, "tree_label": "Feratel CPS - Stati"}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 46, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "currencies_accepted": {"type": "string", "label": "Akzeptierte Währung", "search": true, "sorting": 26, "storage_location": "value"}, "outdoor_active_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - Tags", "sorting": 36, "external": true, "tree_label": "OutdoorActive - Tags", "not_translated": true}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 66, "tree_label": "Lizenzen"}, "feratel_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsklassifizierungen", "sorting": 45, "external": true, "tree_label": "Feratel - Unterkunftsklassifizierungen"}, "accommodation_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftsarten", "sorting": 44, "external": true, "tree_label": "Feratel - Unterkunftsarten"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 56, "external": true, "tree_label": "Feratel - CreativeCommons"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 67, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 7, "translated": true, "template_name": "Öffnungszeit"}, "outdoor_active_system_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Kategorien", "global": true, "sorting": 39, "tree_label": "OutdoorActive - System - Kategorien"}, "feratel_facilities_accommodations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Unterkünfte", "sorting": 47, "external": true, "tree_label": "Feratel - Merkmale - Unterkünfte"}, "outdoor_active_system_source_keys": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "OutdoorActive - System - Quellen", "global": true, "sorting": 40, "tree_label": "OutdoorActive - System - Quellen", "validations": {"max": 1}}, "feratel_facilities_additional_services": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Services", "sorting": 48, "external": true, "tree_label": "Feratel - Merkmale - Services"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.130065	2020-10-29 13:34:02.134802	2020-10-29 13:34:02.134802	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	10.0	entity	\N
a7b0a553-a468-4f5f-8a9f-13cba13277f9	\N	BodyOfWaterOverlay	{"api": {}, "name": "BodyOfWaterOverlay", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Link", "sorting": 3, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Name", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 5, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 4, "template_name": "Bild"}}, "schema_type": "Place", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.330532	2020-10-29 13:34:02.331447	2020-10-29 13:34:02.331447	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
d67d05b9-5db0-4d4d-83e8-01b3cf8eff4a	\N	freie Scheehöhenmesspunkte	{"api": {"type": ["Place", "dcls:SnowHeightMeasuringPoint"]}, "name": "freie Scheehöhenmesspunkte", "type": "object", "boost": 100.0, "features": {"creatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 7, "tree_label": "Inhaltstypen", "default_value": "freie Scheehöhenmesspunkte"}, "snow_report": {"api": {"name": "containsPlace", "partial": "to_linked"}, "type": "embedded", "label": "Schneehöhe - Messpunkt", "sorting": 3, "template_name": "Schneehöhe - Messpunkt", "advanced_search": true}, "snow_resort": {"type": "linked", "label": "Skigebiet", "sorting": 4, "inverse_of": "additional_snow_report", "template_name": "Skigebiet"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 9, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 11, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 12, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 10, "storage_location": "value"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 8, "external": true, "universal": true}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.339409	2020-10-29 13:34:02.340723	2020-10-29 13:34:02.340723	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
e69e4283-370a-48aa-a3ef-50175764a86f	\N	Schneehöhe - Messpunkt	{"api": {}, "name": "Schneehöhe - Messpunkt", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 8, "default_value": "do_not_show", "storage_location": "translated_value"}, "elevation": {"api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 3, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "column"}, "identifier": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "Identifier", "sorting": 6, "storage_location": "translated_value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 10, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 12, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 13, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 11, "storage_location": "value"}, "depth_of_snow": {"ui": {"edit": {"options": {"data-unit": "cm"}}, "show": {"options": {"data-unit": "cm"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "Schneehöhe", "sorting": 4, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "condition_weather": {"type": "classification", "label": "Wetter - Meldung", "sorting": 7, "tree_label": "Bergfex - Wetter - Meldung"}, "depth_of_fresh_snow": {"ui": {"edit": {"options": {"data-unit": "cm"}}, "show": {"options": {"data-unit": "cm"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "Neuschnee", "sorting": 5, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 9, "external": true, "universal": true}}, "schema_type": "Place", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.349952	2020-10-29 13:34:02.351448	2020-10-29 13:34:02.351448	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
effbccde-d381-40ac-bbc8-1a1283c985ae	\N	Skigebiet	{"api": {"type": "SkiResort"}, "name": "Skigebiet", "type": "object", "boost": 100.0, "features": {"overlay": {"allowed": true}, "download": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Link", "sorting": 23, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 3, "normalize": {"id": "eventplace", "type": "eventplace"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "image": {"type": "linked", "label": "Bilder", "sorting": 24, "template_name": "Bild"}, "lifts": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "object", "label": "Lifte", "sorting": 10, "properties": {"value": {"type": "number", "label": "Geöffnete Lifte", "sorting": 1, "validations": {"format": "integer"}, "storage_location": "value"}, "max_value": {"type": "number", "label": "Lifte gesamt", "sorting": 2, "validations": {"format": "integer"}, "storage_location": "value"}}, "storage_location": "value"}, "addons": {"api": {"name": "amenityFeature"}, "type": "embedded", "label": "Addons", "sorting": 16, "template_name": "Skigebiet - Addon"}, "slopes": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "object", "label": "Pistenlänge", "sorting": 11, "properties": {"value": {"type": "number", "label": "Pistenlänge, geöffnete Pisten", "sorting": 1, "validations": {"format": "float"}, "storage_location": "value"}, "max_value": {"type": "number", "label": "Max Pistenlänge", "sorting": 2, "validations": {"format": "float"}, "storage_location": "value"}}, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 37, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 2, "validations": {"max": 1}, "template_name": "SnowResortOverlay"}, "latitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Latitude", "sorting": 18, "normalize": {"id": "latitude", "type": "latitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "location": {"api": {"disabled": true}, "type": "geographic", "label": "GPS-Koordinaten", "sorting": 20, "storage_location": "column"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 31, "tree_label": "Inhaltstypen", "default_value": "Skigebiet"}, "elevation": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Meereshöhe (m)", "sorting": 19, "validations": {"format": "float"}, "storage_location": "column"}, "longitude": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"minimal": true, "transformation": {"name": "geo", "type": "GeoCoordinates", "method": "nest"}}, "type": "number", "label": "Longitude", "sorting": 17, "normalize": {"id": "longitude", "type": "longitude"}, "validations": {"format": "float"}, "storage_location": "column"}, "snow_report": {"api": {"name": "containsPlace", "partial": "to_linked"}, "type": "embedded", "label": "Schneehöhe - Messpunkt", "sorting": 21, "template_name": "Schneehöhe - Messpunkt", "advanced_search": true}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 33, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 35, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 36, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 34, "storage_location": "value"}, "condition_snow": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Schnee - Meldung", "sorting": 30, "external": true, "tree_label": "Bergfex - Schnee - Meldung"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "tourism_region": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tourismus-Region", "global": true, "sorting": 4, "tree_label": "Tourismus-Regionen"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 41, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 40, "external": true, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 39, "external": true, "storage_location": "value"}, "condition_slopes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Pisten - Meldung", "sorting": 29, "external": true, "tree_label": "Bergfex - Pisten - Meldung"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 38, "external": true, "storage_location": "value"}, "count_open_slopes": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "object", "label": "Pisten", "sorting": 12, "properties": {"value": {"type": "number", "label": "Geöffnete Pisten", "sorting": 1, "validations": {"format": "integer"}, "storage_location": "value"}, "max_value": {"type": "number", "label": "Pisten gesamt", "sorting": 2, "validations": {"format": "integer"}, "storage_location": "value"}}, "storage_location": "value"}, "date_last_snowfall": {"ui": {"edit": {"type": "date", "options": {"class": "single_date", "placeholder": "tt.mm.jjjj"}}, "show": {"type": "date"}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "datetime", "label": "Letzter Schneefall", "sorting": 9, "validations": {"format": "date_time"}, "storage_location": "value"}, "bergfex_status_icon": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Status-Icon", "sorting": 7, "external": true, "tree_label": "Bergfex - Status - Icon"}, "date_time_updated_at": {"ui": {"edit": {"type": "datetime", "options": {"class": "single_date", "placeholder": "tt.mm.jjjj --:--"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "datetime", "label": "Zuletzt aktualisiert", "sorting": 8, "validations": {"format": "date_time"}, "storage_location": "value"}, "length_nordic_classic": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "Loipenlänge Nordisch Klassisch", "sorting": 13, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "length_nordic_skating": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "Loipenlänge Nordisch Skating", "sorting": 14, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "additional_snow_report": {"type": "linked", "label": "freie Scheehöhenmesspunkte", "sorting": 22, "inverse_of": "snow_resort", "template_name": "freie Scheehöhenmesspunkte", "link_direction": "inverse"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 42, "tree_label": "Lizenzen"}, "condition_run_to_valley": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Talfahrt - Meldung", "sorting": 28, "external": true, "tree_label": "Bergfex - Talfahrt - Meldung"}, "condition_nordic_classic": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "NordicClassic - Meldung", "sorting": 26, "external": true, "tree_label": "Bergfex - NordicClassic - Meldung"}, "condition_nordic_skating": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "NordicSkating - Meldung", "sorting": 27, "external": true, "tree_label": "Bergfex - NordicClassic - Meldung"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 32, "external": true, "universal": true}, "opening_hours_specification": {"type": "embedded", "label": "Öffnungszeit", "sorting": 15, "translated": true, "template_name": "Öffnungszeit"}, "condition_avalanche_warning_level": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Lawinenwarnlevel", "sorting": 25, "external": true, "tree_label": "Bergfex - Lawinenwarnlevel"}}, "schema_type": "Place", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.369241	2020-10-29 13:34:02.372137	2020-10-29 13:34:02.372137	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
fd068bb3-61ca-488f-adec-ba6a361dcb12	\N	SnowResortOverlay	{"api": {}, "name": "SnowResortOverlay", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Link", "sorting": 3, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Name", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 5, "default_value": "do_not_show", "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 4, "template_name": "Bild"}}, "schema_type": "Place", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.382736	2020-10-29 13:34:02.383665	2020-10-29 13:34:02.383665	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
2544bbd9-7eeb-41c8-a1a7-cfa163eb9bd9	\N	Produkt	{"api": {}, "name": "Produkt", "type": "object", "boost": 100.0, "features": {"creatable": {"allowed": false}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "gtin": {"type": "string", "label": "GTIN", "search": true, "sorting": 14, "storage_location": "value"}, "logo": {"type": "linked", "label": "Logo", "sorting": 9, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Bild"], "treeLabel": "Inhaltstypen"}}], "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 7, "storage_location": "translated_value"}, "color": {"type": "string", "label": "Farbe", "sorting": 20, "storage_location": "translated_value"}, "depth": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "depth", "method": "nest"}}, "type": "number", "label": "Tiefe", "sorting": 17, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 10, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Bild"], "treeLabel": "Inhaltstypen"}}], "template_name": "Bild"}, "model": {"type": "linked", "label": "Produkt - Modell", "sorting": 23, "inverse_of": "is_variant_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Produktmodell"], "treeLabel": "Inhaltstypen"}}]}, "width": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "width", "method": "nest"}}, "type": "number", "label": "Breite", "sorting": 15, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "height": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "height", "method": "nest"}}, "type": "number", "label": "Höhe", "sorting": 16, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "offers": {"type": "embedded", "label": "Angebote", "sorting": 12, "translated": true, "template_name": "Angebot", "advanced_search": true}, "weight": {"ui": {"show": {"options": {"data-unit": "kg"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "KGM", "unit_text": "kilogram", "transformation": {"name": "weight", "method": "nest"}}, "type": "number", "label": "Gewicht", "sorting": 18, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "data_type": {"type": "classification", "label": "Inhaltstype", "sorting": 27, "tree_label": "Inhaltstypen", "default_value": "Produkt"}, "product_id": {"api": {"name": "productID"}, "type": "string", "label": "ProductID", "search": true, "sorting": 13, "storage_location": "value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 22, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 6, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 36, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 38, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 39, "storage_location": "column"}, "manufacturer": {"type": "linked", "label": "Hersteller", "sorting": 11, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Organisation"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 37, "storage_location": "value"}, "is_variant_of": {"type": "linked", "label": "Verknüpft mit", "sorting": 24, "inverse_of": "has_variant", "link_direction": "inverse"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 33, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 32, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 26, "tree_label": "Externer Status", "not_translated": true}, "product_feature": {"type": "embedded", "label": "Produkt Merkmale", "sorting": 19, "translated": true, "template_name": "ProductFeature", "advanced_search": true}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 3, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 21, "translated": true, "template_name": "Action"}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 25, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "additional_information": {"type": "embedded", "label": "Ergänzende Information", "sorting": 8, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 34, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 35, "external": true, "universal": true}}, "schema_type": "Product", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.396937	2020-10-29 13:34:02.399539	2020-10-29 13:34:02.399539	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
ed1bcfe6-07f3-4905-9d13-48cda011b12b	\N	Produktgruppe	{"api": {}, "name": "Produktgruppe", "type": "object", "boost": 100.0, "features": {"creatable": {"allowed": false}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "gtin": {"type": "string", "label": "GTIN", "search": true, "sorting": 14, "storage_location": "value"}, "logo": {"type": "linked", "label": "Logo", "sorting": 9, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Bild"], "treeLabel": "Inhaltstypen"}}], "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 7, "storage_location": "translated_value"}, "color": {"type": "string", "label": "Farbe", "sorting": 20, "storage_location": "translated_value"}, "depth": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "depth", "method": "nest"}}, "type": "number", "label": "Tiefe", "sorting": 17, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 10, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Bild"], "treeLabel": "Inhaltstypen"}}], "template_name": "Bild"}, "width": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "width", "method": "nest"}}, "type": "number", "label": "Breite", "sorting": 15, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "height": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "height", "method": "nest"}}, "type": "number", "label": "Höhe", "sorting": 16, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "offers": {"type": "embedded", "label": "Angebote", "sorting": 12, "translated": true, "template_name": "Angebot", "advanced_search": true}, "weight": {"ui": {"show": {"options": {"data-unit": "kg"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "KGM", "unit_text": "kilogram", "transformation": {"name": "weight", "method": "nest"}}, "type": "number", "label": "Gewicht", "sorting": 18, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 28, "external": true, "storage_location": "value"}, "data_type": {"type": "classification", "label": "Inhaltstype", "sorting": 26, "tree_label": "Inhaltstypen", "default_value": "Produktgruppe"}, "product_id": {"api": {"name": "productID"}, "type": "string", "label": "ProductID", "search": true, "sorting": 13, "storage_location": "value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 22, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 6, "storage_location": "column"}, "has_variant": {"type": "linked", "label": "Produkt", "sorting": 23, "inverse_of": "is_variant_of", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Produkt"], "treeLabel": "Inhaltstypen"}}]}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 35, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 37, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 38, "storage_location": "column"}, "manufacturer": {"type": "linked", "label": "Hersteller", "sorting": 11, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Organisation"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 36, "storage_location": "value"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 32, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 25, "tree_label": "Externer Status", "not_translated": true}, "product_feature": {"type": "embedded", "label": "Produkt Merkmale", "sorting": 19, "translated": true, "template_name": "ProductFeature", "advanced_search": true}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 3, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 21, "translated": true, "template_name": "Action"}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 24, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "additional_information": {"type": "embedded", "label": "Ergänzende Information", "sorting": 8, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 33, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 34, "external": true, "universal": true}}, "schema_type": "ProductGroup", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.416501	2020-10-29 13:34:02.419287	2020-10-29 13:34:02.419287	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
b138c0b2-3761-4fa3-9fe0-b8ad15bb46fd	\N	Produktmodel	{"api": {}, "name": "Produktmodel", "type": "object", "boost": 100.0, "features": {"creatable": {"allowed": false}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "gtin": {"type": "string", "label": "GTIN", "search": true, "sorting": 14, "storage_location": "value"}, "logo": {"type": "linked", "label": "Logo", "sorting": 9, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Bild"], "treeLabel": "Inhaltstypen"}}], "template_name": "Bild"}, "name": {"ui": {"show": {"content_area": "none"}}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 4, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 7, "storage_location": "translated_value"}, "color": {"type": "string", "label": "Farbe", "sorting": 20, "storage_location": "translated_value"}, "depth": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "depth", "method": "nest"}}, "type": "number", "label": "Tiefe", "sorting": 17, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 10, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Bild"], "treeLabel": "Inhaltstypen"}}], "template_name": "Bild"}, "width": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "width", "method": "nest"}}, "type": "number", "label": "Breite", "sorting": 15, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "height": {"ui": {"show": {"options": {"data-unit": "m"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "MTR", "unit_text": "metre", "transformation": {"name": "height", "method": "nest"}}, "type": "number", "label": "Höhe", "sorting": 16, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "offers": {"type": "embedded", "label": "Angebote", "sorting": 12, "translated": true, "template_name": "Angebot", "advanced_search": true}, "weight": {"ui": {"show": {"options": {"data-unit": "kg"}}}, "api": {"type": "QuantitativeValue", "partial": "property_value", "unit_code": "KGM", "unit_text": "kilogram", "transformation": {"name": "weight", "method": "nest"}}, "type": "number", "label": "Gewicht", "sorting": 18, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 28, "external": true, "storage_location": "value"}, "data_type": {"type": "classification", "label": "Inhaltstype", "sorting": 26, "tree_label": "Inhaltstypen", "default_value": "Produktmodel"}, "product_id": {"api": {"name": "productID"}, "type": "string", "label": "ProductID", "search": true, "sorting": 13, "storage_location": "value"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 22, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 6, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 35, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 37, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 38, "storage_location": "column"}, "manufacturer": {"type": "linked", "label": "Hersteller", "sorting": 11, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Organisation"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 36, "storage_location": "value"}, "is_variant_of": {"type": "linked", "label": "Verknüpft mit", "sorting": 23, "inverse_of": "model", "link_direction": "inverse"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 5, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 32, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 25, "tree_label": "Externer Status", "not_translated": true}, "product_feature": {"type": "embedded", "label": "Produkt Merkmale", "sorting": 19, "translated": true, "template_name": "ProductFeature", "advanced_search": true}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 3, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 30, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 29, "external": true, "storage_location": "value"}, "potential_action": {"api": {"partial": "action"}, "type": "embedded", "label": "Weiterführende Links", "sorting": 21, "translated": true, "template_name": "Action"}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 24, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "additional_information": {"type": "embedded", "label": "Ergänzende Information", "sorting": 8, "template_name": "Ergänzende Information"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 33, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 34, "external": true, "universal": true}}, "schema_type": "ProductModel", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.436477	2020-10-29 13:34:02.443781	2020-10-29 13:34:02.443781	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
d322aebe-8722-42ca-8ce7-a79f12d46d45	\N	Pauschalangebot	{"api": {"type": "AggregateOffer"}, "name": "Pauschalangebot", "type": "object", "boost": 100.0, "features": {"creatable": {"allowed": true}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"v4": {"name": "sameAs"}}, "type": "string", "label": "Angebots URL", "sorting": 21, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 7, "tree_label": "Tags"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung (lang)", "search": true, "sorting": 4, "storage_location": "translated_value"}, "image": {"api": {"v4": {"name": "image"}, "name": "photo", "minimal": true}, "type": "linked", "label": "Bilder", "sorting": 26, "template_name": "Bild"}, "offers": {"type": "embedded", "label": "Angebote", "sorting": 23, "translated": true, "template_name": "Angebot", "advanced_search": true}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "data_type": {"type": "classification", "label": "Inhaltstype", "sorting": 29, "tree_label": "Inhaltstypen", "default_value": "Pauschalangebot"}, "low_price": {"type": "number", "label": "ab Preis", "sorting": 17, "validations": {"format": "float"}, "storage_location": "value"}, "high_price": {"type": "number", "label": "bis Preis", "sorting": 18, "validations": {"format": "float"}, "storage_location": "value"}, "offered_by": {"type": "linked", "label": "Ansprechpartner", "sorting": 22, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 3, "storage_location": "column"}, "content_text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "transformation": {"name": "dataCycleProperty", "method": "nest"}}, "type": "string", "label": "Inhaltsbeschreibung (lang)", "search": true, "sorting": 6, "storage_location": "translated_value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 38, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 40, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 41, "storage_location": "column"}, "offer_period": {"ui": {"edit": {"type": "daterange"}}, "api": {"transformation": {"method": "unwrap"}}, "type": "object", "label": "Angebotszeitraum", "sorting": 24, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Zeitraum von", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_through": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "show": {"type": "date"}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_through", "from": "valid_from"}}, "storage_location": "value"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 39, "storage_location": "value"}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 16, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 9, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 12, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 8, "tree_label": "Ausgabekanäle"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 35, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 34, "external": true, "storage_location": "value"}, "eligable_region": {"api": {"v4": {"name": "eligibleRegion"}}, "type": "linked", "label": "Anbieter", "sorting": 20, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 28, "tree_label": "Externer Status", "not_translated": true}, "potentialAction": {"api": {"type": "Action"}, "type": "object", "label": "Buchungs-Url", "sorting": 25, "properties": {"url": {"type": "string", "label": "URL", "sorting": 2, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Name", "sorting": 1, "storage_location": "translated_value"}}, "storage_location": "translated_value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 33, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 32, "external": true, "storage_location": "value"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 15, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "feratel_price_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Preis - Typ", "sorting": 14, "external": true, "tree_label": "Feratel - Preis - Typ", "not_translated": true}, "content_description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"v4": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "transformation": {"name": "dataCycleProperty", "method": "nest"}}, "type": "string", "label": "Inhaltsbeschreibung", "search": true, "sorting": 5, "storage_location": "translated_value"}, "price_specification": {"type": "embedded", "label": "Preis", "sorting": 19, "translated": true, "template_name": "Preis", "advanced_search": true}, "feratel_offer_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Angebot - Status", "sorting": 13, "external": true, "tree_label": "Feratel - Angebot - Status", "not_translated": true}, "feratel_product_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Produktarten", "sorting": 11, "external": true, "tree_label": "Feratel - Produktarten", "not_translated": true}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 27, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 36, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 37, "external": true, "universal": true}, "feratel_accommodation_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftstypen", "sorting": 10, "external": true, "tree_label": "Feratel - Unterkunftstypen", "not_translated": true}}, "schema_type": "Intangible", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.463308	2020-10-29 13:34:02.466166	2020-10-29 13:34:02.466166	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
9fb00589-8d53-4e0f-be8b-2024f58d8a33	\N	Durchschnittswertung	{"api": {"type": "AggregateRating"}, "name": "Durchschnittswertung", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 5, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 7, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 8, "storage_location": "column"}, "rating_count": {"type": "number", "label": "Anzahl Wertungen", "sorting": 2, "storage_location": "value"}, "rating_value": {"type": "number", "label": "Wertung", "sorting": 3, "validations": {"format": "float"}, "storage_location": "value"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 6, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 4, "external": true, "universal": true}}, "schema_type": "Intangible", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.477027	2020-10-29 13:34:02.47811	2020-10-29 13:34:02.47811	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
304c87c3-69ed-4aed-aeee-b102f293d7a0	\N	AmenityFeature	{"api": {"type": "PropertyValue"}, "name": "AmenityFeature", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Titel", "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 4, "default_value": "do_not_show", "storage_location": "translated_value"}, "value": {"type": "number", "label": "Wert", "sorting": 3, "storage_location": "value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 6, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 8, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 9, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 7, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 5, "external": true, "universal": true}}, "schema_type": "Intangible", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.48525	2020-10-29 13:34:02.486425	2020-10-29 13:34:02.486425	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
9029bac0-06a1-4a36-8bcd-23799051070f	\N	Angebot	{"api": {"type": "Offer"}, "name": "Angebot", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"v4": {"name": "sameAs"}}, "type": "string", "label": "Angebots URL", "sorting": 14, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung (lang)", "search": true, "sorting": 4, "storage_location": "translated_value"}, "price": {"type": "string", "label": "Preis", "sorting": 12, "storage_location": "translated_value"}, "offered_by": {"type": "linked", "label": "Ansprechpartner", "sorting": 15, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "LocalBusiness"], "treeLabel": "Inhaltstypen"}}]}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 3, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 20, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 22, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 23, "storage_location": "column"}, "item_offered": {"type": "linked", "label": "Angebotene Leistung", "sorting": 16, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Unterkunft", "Service"], "treeLabel": "Inhaltstypen"}}]}, "offer_period": {"ui": {"edit": {"type": "daterange"}}, "api": {"transformation": {"method": "unwrap"}}, "type": "object", "label": "Angebotszeitraum", "sorting": 17, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Zeitraum von", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_through": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "show": {"type": "date"}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_through", "from": "valid_from"}}, "storage_location": "value"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 21, "storage_location": "value"}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 5, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 8, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "potentialAction": {"api": {"type": "Action"}, "type": "object", "label": "Buchungs-Url", "sorting": 18, "properties": {"url": {"type": "string", "label": "URL", "sorting": 2, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Name", "sorting": 1, "storage_location": "translated_value"}}, "storage_location": "translated_value"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 11, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "feratel_price_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Preis - Typ", "sorting": 10, "external": true, "tree_label": "Feratel - Preis - Typ", "not_translated": true}, "price_specification": {"type": "embedded", "label": "Preis", "sorting": 13, "tranlated": true, "template_name": "Preis", "advanced_search": true}, "feratel_offer_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Angebot - Status", "sorting": 9, "external": true, "tree_label": "Feratel - Angebot - Status", "not_translated": true}, "feratel_product_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Produktarten", "sorting": 7, "external": true, "tree_label": "Feratel - Produktarten", "not_translated": true}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 19, "external": true, "universal": true}, "feratel_accommodation_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Unterkunftstypen", "sorting": 6, "external": true, "tree_label": "Feratel - Unterkunftstypen", "not_translated": true}}, "schema_type": "Intangible", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.498226	2020-10-29 13:34:02.500083	2020-10-29 13:34:02.500083	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
b5eb933d-61df-4e5b-8531-91550b4a887c	\N	ProductFeature	{"api": {"type": "PropertyValue"}, "name": "ProductFeature", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Titel", "sorting": 2, "storage_location": "column"}, "value": {"type": "string", "label": "Wert", "sorting": 3, "storage_location": "translated_value"}, "unit_text": {"type": "string", "label": "Einheit", "sorting": 4, "storage_location": "translated_value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 6, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 8, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 9, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 7, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 5, "external": true, "universal": true}}, "schema_type": "Intangible", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.508766	2020-10-29 13:34:02.50984	2020-10-29 13:34:02.50984	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
79c23905-7aed-4f92-8bb4-275a54d7e1bf	\N	Service	{"api": {}, "name": "Service", "type": "object", "boost": 1.0, "features": {"creatable": {"allowed": true}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"v4": {"name": "sameAs"}}, "type": "string", "label": "Angebots URL", "sorting": 9, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "text": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Beschreibung (lang)", "search": true, "sorting": 4, "storage_location": "translated_value"}, "image": {"type": "linked", "label": "Bilder", "sorting": 5, "template_name": "Bild"}, "offers": {"type": "embedded", "label": "Angebote", "sorting": 11, "translated": true, "template_name": "Angebot"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 17, "external": true, "storage_location": "value"}, "provider": {"type": "linked", "label": "Dienstleister", "sorting": 6, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["LocalBusiness", "Unterkunft", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "data_type": {"type": "classification", "label": "Inhaltstype", "sorting": 16, "tree_label": "Inhaltstypen", "default_value": "Service"}, "subject_of": {"type": "embedded", "label": "Ergänzende Information", "sorting": 8, "template_name": "Ergänzende Information"}, "area_served": {"type": "linked", "label": "Treffpunkt", "sorting": 7, "template_name": "Örtlichkeit"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 3, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 24, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 26, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 27, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 25, "storage_location": "value"}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 12, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 21, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 20, "external": true, "storage_location": "value"}, "hours_available": {"api": {"v4": {"disabled": false}, "disabled": true}, "type": "schedule", "label": "Termine", "sorting": 10}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 19, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 18, "external": true, "storage_location": "value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 22, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 23, "external": true, "universal": true}, "feratel_additional_service_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - AdditionalServiceTypes", "sorting": 13, "external": true, "tree_label": "Feratel - AdditionalServiceTypes", "not_translated": true}, "feratel_guest_card_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - GuestCardClassifications", "sorting": 14, "external": true, "tree_label": "Feratel - GuestCardClassifications", "not_translated": true}, "feratel_facilities_additional_services": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Services", "sorting": 15, "external": true, "tree_label": "Feratel - Merkmale - Services"}}, "schema_type": "Intangible", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.521048	2020-10-29 13:34:02.522981	2020-10-29 13:34:02.522981	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	entity	\N
58b7f935-2139-4937-af69-9c188632861c	\N	Preis	{"api": {"type": "UnitPriceSpecification"}, "name": "Preis", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "price": {"type": "number", "label": "Preis", "sorting": 2, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "max_price": {"type": "number", "label": "Max-Preis", "sorting": 4, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "min_price": {"type": "number", "label": "Min-Preis", "sorting": 3, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "value"}, "unit_text": {"type": "string", "label": "Einheit", "sorting": 6, "storage_location": "translated_value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 10, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 12, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 13, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 11, "storage_location": "value"}, "price_currency": {"type": "classification", "label": "Währung", "sorting": 5, "tree_label": "Preis-Währung", "default_value": "EUR"}, "validity_period": {"ui": {"edit": {"type": "daterange"}}, "api": {"transformation": {"method": "unwrap"}}, "type": "object", "label": "Angebotszeitraum", "sorting": 7, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "show": {"type": "date"}}, "type": "datetime", "label": "Gültig ab", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_through": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}, "show": {"type": "date"}}, "api": {"name": "validThrough"}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_through", "from": "valid_from"}}, "storage_location": "value"}, "feratel_meal_code": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Verpflegungs Kürzel", "sorting": 8, "external": true, "tree_label": "Feratel - Verpflegungs Kürzel"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 9, "external": true, "universal": true}}, "schema_type": "Intangible", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.533359	2020-10-29 13:34:02.534733	2020-10-29 13:34:02.534733	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
7c36a3b0-7093-44a4-af74-961432289d4e	\N	VirtualLocation	{"api": {"type": "VirtualLocation"}, "name": "VirtualLocation", "type": "object", "boost": 1.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"type": "string", "label": "URL", "sorting": 3, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Titel", "search": true, "sorting": 2, "storage_location": "column"}, "dummy": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "xml": {"disabled": true}, "type": "string", "label": "invisible", "sorting": 4, "default_value": "do_not_show", "storage_location": "translated_value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 6, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 8, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 9, "storage_location": "column"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 7, "storage_location": "value"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 5, "external": true, "universal": true}}, "schema_type": "Intangible", "content_type": "embedded"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.543111	2020-10-29 13:34:02.544328	2020-10-29 13:34:02.544328	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	1.0	embedded	\N
d6a8bafc-498f-423e-a43e-499bdd5ec383	\N	JobPosting	{"api": {"type": "JobPosting"}, "name": "JobPosting", "type": "object", "boost": 100.0, "features": {"creatable": {"allowed": false}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 2, "validations": {"required": true}, "storage_location": "column"}, "state": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Bundesland", "sorting": 14, "external": true, "tree_label": "karriere.at - States"}, "title": {"ui": {"show": {"disabled": true}}, "api": {"minimal": true}, "type": "computed", "label": "API-Titel", "compute": {"type": "string", "method": "concat", "module": "Utility::Compute::String", "parameters": {"0": {"name": "name", "type": "content"}}}, "sorting": 3, "storage_location": "translated_value"}, "country": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Land", "sorting": 13, "external": true, "tree_label": "karriere.at - Countries"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 21, "external": true, "storage_location": "value"}, "snippet": {"api": {"name": "snippet", "type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "string", "label": "Kurzbeschreibung", "search": true, "sorting": 5, "storage_location": "translated_value"}, "keywords": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Job Keywords", "sorting": 15, "external": true, "tree_label": "karriere.at - Keywords"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 10, "tree_label": "Inhaltstypen", "default_value": "Job"}, "job_fields": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Berufsfelder", "sorting": 11, "external": true, "tree_label": "karriere.at - Job Fields"}, "date_posted": {"type": "datetime", "label": "Veröffentlichungsdatum", "sorting": 7, "storage_location": "value"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "basic"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 4, "storage_location": "column"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 17, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 19, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 20, "storage_location": "column"}, "job_location": {"type": "linked", "label": "Arbeitsort", "sorting": 9, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 18, "storage_location": "value"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 25, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 24, "external": true, "storage_location": "value"}, "employment_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Anstellungsart", "sorting": 12, "external": true, "tree_label": "karriere.at - Employment Types"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 23, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 22, "external": true, "storage_location": "value"}, "potential_action": {"api": {"type": "ViewAction"}, "type": "object", "label": "GoogleAnalytics Link", "sorting": 6, "properties": {"url": {"type": "string", "label": "URL", "sorting": 2, "storage_location": "translated_value"}, "name": {"type": "string", "label": "Name", "sorting": 1, "default_value": "Link", "storage_location": "translated_value"}}, "storage_location": "translated_value"}, "hiring_organization": {"type": "linked", "label": "Arbeitgeber", "sorting": 8, "template_name": "Organization"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 26, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 16, "external": true, "universal": true}}, "schema_type": "Intangible", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.556078	2020-10-29 13:34:02.557977	2020-10-29 13:34:02.557977	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
892e15ba-abfc-4640-88d6-a349a543f6dc	\N	Zertifizierung	{"api": {"type": "dc:certification"}, "name": "Zertifizierung", "type": "object", "boost": 100.0, "features": {}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "name": {"type": "string", "label": "Zertifiziert", "search": true, "sorting": 2, "storage_location": "column"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 18, "external": true, "storage_location": "value"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 12, "tree_label": "Inhaltstypen", "default_value": "Reisen für Alle"}, "public_pdf": {"type": "object", "label": "Detailberichte zur Barrierefreiheit zum Download", "sorting": 7, "properties": {"deaf": {"type": "string", "label": "Hörbehinderte/Gehörlose", "sorting": 2, "storage_location": "translated_value"}, "mental": {"type": "string", "label": "Kognitiv Beeinträchtigte", "sorting": 4, "storage_location": "translated_value"}, "visual": {"type": "string", "label": "Sehbehinderte/Blinde", "sorting": 3, "storage_location": "translated_value"}, "wheelchair": {"type": "string", "label": "Gehbehinderte/Rollstuhlfahrer", "sorting": 1, "storage_location": "translated_value"}}, "storage_location": "translated_value"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 14, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 16, "storage_location": "value"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 17, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 4, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 3, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "short_report": {"type": "object", "label": "Kurzbericht", "sorting": 8, "properties": {"deaf": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Hörbehinderte/Gehörlose", "search": true, "sorting": 2, "storage_location": "translated_value"}, "mental": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Kognitiv Beeinträchtigte", "search": true, "sorting": 4, "storage_location": "translated_value"}, "visual": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Sehbehinderte/Blinde", "search": true, "sorting": 3, "storage_location": "translated_value"}, "walking": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Gehbehinderte/Rollstuhlfahrer", "search": true, "sorting": 1, "storage_location": "translated_value"}}, "storage_location": "translated_value"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 15, "storage_location": "value"}, "licence_owner": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Lizenznehmer", "global": true, "sorting": 10, "tree_label": "reisen-fuer-alle.de - Lizenznehmer"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 22, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 21, "external": true, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 20, "external": true, "storage_location": "value"}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 19, "external": true, "storage_location": "value"}, "short_report_pdf": {"type": "linked", "label": "Prüfbericht Reisen für Alle", "global": true, "sorting": 9, "template_name": "PDF"}, "certification_type": {"type": "object", "label": "Zertifizierungstyp", "sorting": 6, "properties": {"key": {"type": "string", "label": "Wert", "search": true, "sorting": 2, "storage_location": "translated_value"}, "icon": {"type": "string", "label": "Symbol", "sorting": 3, "storage_location": "translated_value"}, "designation": {"type": "string", "label": "Bezeichnung", "search": true, "sorting": 1, "storage_location": "translated_value"}}, "storage_location": "translated_value"}, "certification_period": {"ui": {"edit": {"type": "daterange"}}, "type": "object", "label": "Zertifizierungszeitraum", "sorting": 5, "properties": {"certified_to": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}, "certified_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Zertifizierung", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "certified_to", "from": "certified_from"}}, "storage_location": "value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 23, "tree_label": "Lizenzen"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 13, "external": true, "universal": true}, "certificate_classification": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Zertifizierungen", "global": true, "sorting": 11, "tree_label": "reisen-fuer-alle.de - Zertifikate"}}, "schema_type": "Intangible", "content_type": "entity"}	t	\N	\N	\N	\N	\N	\N	2020-10-29 13:34:02.578573	2020-10-29 13:34:02.580668	2020-10-29 13:34:02.580668	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
9ac37e86-80b6-413f-b8f0-d960ffee22d1	{"license": null, "date_created": null, "date_deleted": null, "date_modified": null, "attribution_url": null, "validity_period": {"valid_from": null, "valid_until": null}, "attribution_name": null, "more_permissions": null}	Event	{"api": {}, "name": "Event", "type": "object", "boost": 100.0, "features": {"overlay": {"allowed": true}, "download": {"allowed": true}, "creatable": {"allowed": true}, "serialize": {"allowed": true, "serializers": {"xml": true, "json": true, "indesign": true}}, "translatable": {"allowed": true}}, "properties": {"id": {"type": "key", "label": "id", "sorting": 1}, "url": {"api": {"name": "sameAs"}, "xml": {"name": "sameAs"}, "type": "string", "label": "Inhalt URL", "sorting": 10, "validations": {"format": "url"}, "storage_location": "translated_value"}, "name": {"ui": {"show": {"content_area": "none"}}, "api": {"minimal": true}, "type": "string", "label": "Titel", "search": true, "sorting": 3, "normalize": {"id": "eventname", "type": "eventname"}, "validations": {"required": true}, "storage_location": "column"}, "tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Tags", "global": true, "sorting": 5, "tree_label": "Tags"}, "image": {"type": "linked", "label": "Bilder", "sorting": 12, "template_name": "Bild"}, "offers": {"type": "embedded", "label": "Angebote", "sorting": 23, "translated": true, "template_name": "Angebot"}, "license": {"api": {"v4": {"name": "cc:license"}}, "type": "string", "label": "Copyright / Lizenz", "search": true, "sorting": 31, "external": true, "storage_location": "value"}, "overlay": {"type": "embedded", "label": "Overlay", "sorting": 2, "validations": {"max": 1}, "template_name": "EventOverlay"}, "same_as": {"api": {"name": "link", "type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "xml": {"name": "link"}, "type": "string", "label": "Link", "sorting": 11, "validations": {"format": "url"}, "storage_location": "translated_value"}, "end_date": {"ui": {"show": {"content_area": "none"}}, "type": "computed", "label": "Endzeitpunkt", "compute": {"type": "datetime", "method": "end_date", "module": "Utility::Compute::Schedule", "parameters": {"0": "event_schedule"}}, "sorting": 8, "storage_location": "column"}, "schedule": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"v4": {"disabled": true}, "name": "eventSchedule"}, "type": "embedded", "label": "Event-Schedule", "sorting": 19, "translated": true, "template_name": "EventSchedule"}, "data_type": {"type": "classification", "label": "Inhaltstyp", "sorting": 30, "tree_label": "Inhaltstypen", "default_value": "Veranstaltung"}, "event_tag": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Veranstaltungsdatenbank - Tag", "sorting": 43, "external": true, "tree_label": "Veranstaltungsdatenbank - Tag"}, "organizer": {"type": "linked", "label": "Veranstalter", "sorting": 22, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "LocalBusiness"], "treeLabel": "Inhaltstypen"}}]}, "performer": {"type": "linked", "label": "Ausführende Person/Organisation", "sorting": 21, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation"], "treeLabel": "Inhaltstypen"}}]}, "sub_event": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"v4": {"disabled": true}}, "type": "embedded", "label": "Veranstaltungsdaten", "sorting": 18, "template_name": "SubEvent"}, "start_date": {"ui": {"show": {"content_area": "none"}}, "type": "computed", "label": "Startzeitpunkt", "compute": {"type": "datetime", "method": "start_date", "module": "Utility::Compute::Schedule", "parameters": {"0": "event_schedule"}}, "sorting": 7, "storage_location": "column"}, "subject_of": {"type": "linked", "label": "Thema von", "global": true, "sorting": 27, "inverse_of": "about", "link_direction": "inverse"}, "description": {"ui": {"edit": {"type": "text_editor", "options": {"data-size": "full"}}}, "type": "string", "label": "Beschreibung", "search": true, "sorting": 9, "storage_location": "column"}, "puglia_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPuglia - Types", "sorting": 57, "external": true, "tree_label": "EventsPuglia - Types"}, "super_event": {"type": "linked", "label": "Veranstaltungsserie", "sorting": 20, "inverse_of": "sub_event", "template_name": "Eventserie"}, "date_created": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Erstellungsdatum", "sorting": 38, "storage_location": "value"}, "date_deleted": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Gelöschtdatum", "sorting": 40, "storage_location": "value"}, "event_status": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"v4": {"partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Veranstaltungsstatus", "sorting": 16, "tree_label": "Veranstaltungsstatus"}, "external_key": {"ui": {"edit": {"disabled": true}, "show": {"disabled": true}}, "api": {"disabled": true}, "type": "string", "label": "external_key", "sorting": 41, "storage_location": "column"}, "is_linked_to": {"api": {"v4": {"name": "dc:isLinkedTo"}}, "type": "linked", "label": "Verknüpft mit", "global": true, "sorting": 26, "inverse_of": "linked_thing", "link_direction": "inverse"}, "linked_thing": {"api": {"v4": {"name": "dc:linkedThing"}}, "type": "linked", "label": "Verknüpfte Inhalte", "global": true, "sorting": 25, "inverse_of": "is_linked_to", "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Person", "Organisation", "Ort", "Veranstaltung", "Veranstaltungsserie"], "treeLabel": "Inhaltstypen"}}]}, "piemonte_tag": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - Tags", "sorting": 60, "external": true, "tree_label": "EventsPiemonte - Tags"}, "date_modified": {"ui": {"edit": {"disabled": true}, "show": {"type": "date"}}, "type": "datetime", "label": "Änderungsdatum", "sorting": 39, "storage_location": "value"}, "v_ticket_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "V-Ticket Tags", "sorting": 45, "external": true, "tree_label": "VTicket - Tags"}, "event_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Veranstaltungsdatenbank - Kategorien", "sorting": 42, "external": true, "tree_label": "Veranstaltungsdatenbank - Kategorien"}, "event_schedule": {"api": {"v4": {"disabled": false}, "disabled": true}, "type": "schedule", "label": "Termine", "sorting": 17, "validations": {"valid_dates": true}}, "feratel_owners": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Inhaber", "sorting": 48, "external": true, "tree_label": "Feratel - Inhaber", "not_translated": true}, "feratel_status": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Status", "sorting": 51, "external": true, "tree_label": "Feratel - Status", "not_translated": true}, "holiday_themes": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Urlaubsthemen", "sorting": 46, "external": true, "tree_label": "Feratel - Urlaubsthemen"}, "output_channel": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Ausgabekanal", "global": true, "sorting": 6, "tree_label": "Ausgabekanäle"}, "piemonte_scope": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - Scopes", "sorting": 62, "external": true, "tree_label": "EventsPiemonte - Scopes"}, "use_guidelines": {"api": {"v4": {"name": "cc:useGuidelines"}}, "type": "string", "label": "Verwendungsrichtlinie", "search": true, "sorting": 35, "external": true, "storage_location": "translated_value"}, "attribution_url": {"api": {"v4": {"name": "cc:attributionUrl"}}, "type": "string", "label": "Namensnennung - Url", "search": true, "sorting": 34, "external": true, "storage_location": "value"}, "external_status": {"ui": {"edit": {"disabled": true}, "show": {"content_area": "header"}}, "type": "classification", "label": "Externer Status", "global": true, "sorting": 29, "tree_label": "Externer Status", "not_translated": true}, "puglia_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPuglia - Categories", "sorting": 58, "external": true, "tree_label": "EventsPuglia - Categories"}, "validity_period": {"ui": {"edit": {"type": "daterange"}, "show": {"content_area": "none"}}, "api": {"disabled": true}, "type": "object", "label": "Gültigkeitszeitraum", "sorting": 4, "properties": {"valid_from": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "Gültigkeit", "sorting": 1, "validations": {"format": "date_time"}, "storage_location": "value"}, "valid_until": {"ui": {"edit": {"type": "date", "options": {"placeholder": "tt.mm.jjjj", "data-validate": "daterange"}}}, "type": "datetime", "label": "bis", "sorting": 2, "validations": {"format": "date_time"}, "storage_location": "value"}}, "validations": {"daterange": {"to": "valid_until", "from": "valid_from"}}, "storage_location": "value"}, "attribution_name": {"api": {"v4": {"name": "cc:attributionName"}}, "type": "string", "label": "Namensnennung", "search": true, "sorting": 33, "external": true, "storage_location": "value"}, "content_location": {"api": {"name": "location"}, "type": "linked", "label": "Veranstaltungsort", "sorting": 13, "stored_filter": [{"with_classification_aliases_and_treename": {"aliases": ["Ort"], "treeLabel": "Inhaltstypen"}}]}, "more_permissions": {"api": {"v4": {"name": "cc:morePermissions"}}, "type": "string", "label": "Weitere Kriterien", "search": true, "sorting": 32, "external": true, "storage_location": "value"}, "potential_action": {"api": {"type": "ViewAction", "partial": "action", "transformation": {"name": "potentialAction", "method": "append"}}, "type": "string", "label": "Link mit weiterführenden Infos", "sorting": 24, "storage_location": "translated_value"}, "virtual_location": {"api": {"v4": {"disabled": false, "transformation": {"name": "location", "method": "append"}}, "disabled": true}, "type": "embedded", "label": "Virtueller Veranstaltungsort", "sorting": 14, "template_name": "VirtualLocation"}, "feratel_locations": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ort", "sorting": 49, "external": true, "tree_label": "Feratel - Orte", "not_translated": true}, "hrs_dd_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "HRS Destination Data - Classifications", "sorting": 54, "external": true, "tree_label": "HRS Destination Data - Classifications"}, "piemonte_category": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - Categories", "sorting": 61, "external": true, "tree_label": "EventsPiemonte - Categories"}, "piemonte_coverage": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - Coverages", "sorting": 63, "external": true, "tree_label": "EventsPiemonte - Coverages"}, "feratel_event_tags": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Veranstaltungstags", "sorting": 47, "external": true, "tree_label": "Feratel - Veranstaltungstags"}, "feratel_facilities": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Ausstattungsmerkmale", "sorting": 50, "external": true, "tree_label": "Feratel - Ausstattungsmerkmale"}, "puglia_ticket_type": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPuglia - Ticket-Types", "sorting": 59, "external": true, "tree_label": "EventsPuglia - Ticket-Types"}, "v_ticket_categories": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "V-Ticket Categories", "sorting": 44, "external": true, "tree_label": "VTicket - Categories"}, "piemonte_data_source": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsPiemonte - DataSources", "sorting": 64, "external": true, "tree_label": "EventsPiemonte - DataSources"}, "event_attendance_mode": {"ui": {"edit": {"type": "radio_button"}, "show": {"content_area": "header"}}, "api": {"v4": {"partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Veranstaltungsteilnahmemodus", "sorting": 15, "tree_label": "Veranstaltungsteilnahmemodus"}, "feratel_content_score": {"api": {"type": "PropertyValue", "partial": "property_value", "transformation": {"name": "additionalProperty", "method": "combine"}}, "type": "number", "label": "ContentScore", "sorting": 28, "external": true, "validations": {"format": "float"}, "advanced_search": true, "storage_location": "translated_value"}, "license_classification": {"ui": {"show": {"content_area": "header"}}, "api": {"v4": {"name": "cc:license", "partial": "string", "disabled": false}, "disabled": true}, "type": "classification", "label": "Lizenzen", "global": true, "sorting": 36, "tree_label": "Lizenzen"}, "marche_classifications": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "EventsMarche - Classifications", "sorting": 56, "external": true, "tree_label": "EventsMarche - Classifications"}, "feratel_creative_commons": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - CreativeCommons", "sorting": 52, "external": true, "tree_label": "Feratel - CreativeCommons"}, "feratel_facilities_events": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "Feratel - Merkmale - Events", "sorting": 53, "external": true, "tree_label": "Feratel - Merkmale - Events"}, "universal_classifications": {"ui": {"show": {"partial": "universal_classifications", "content_area": "header"}}, "type": "classification", "label": "Classifications", "sorting": 37, "external": true, "universal": true}, "open_destination_one_keywords": {"ui": {"show": {"content_area": "header"}}, "type": "classification", "label": "open.destination.one - Keywords", "sorting": 55, "external": true, "tree_label": "open.destination.one - Keywords"}}, "schema_type": "Event", "content_type": "entity"}	f	\N	\N	\N	e123d2d0-a678-4a95-b447-be62ca039ddf	e123d2d0-a678-4a95-b447-be62ca039ddf	\N	\N	2020-10-29 13:34:35.929846	2020-10-29 13:34:35.951141	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	(,infinity]	100.0	entity	\N
\.


--
-- TOC entry 4334 (class 0 OID 21596)
-- Dependencies: 223
-- Data for Name: user_group_users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_group_users (id, user_group_id, user_id, seen_at, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4333 (class 0 OID 21586)
-- Dependencies: 222
-- Data for Name: user_groups; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_groups (id, name, seen_at, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 4325 (class 0 OID 21116)
-- Dependencies: 214
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, given_name, email, encrypted_password, reset_password_token, reset_password_sent_at, remember_created_at, sign_in_count, current_sign_in_at, last_sign_in_at, current_sign_in_ip, last_sign_in_ip, created_at, updated_at, family_name, locked_at, external, role_id, notification_frequency, access_token, type, name, default_locale, provider, uid, jti, creator_id, additional_attributes, confirmation_token, confirmed_at, confirmation_sent_at, unconfirmed_email) FROM stdin;
e123d2d0-a678-4a95-b447-be62ca039ddf	Administrator	admin@datacycle.at	$2a$11$stNhERuVPg4nwSW6oYGwo..kD2Oj0TyxjaF7GGQ06oRmuZaDUn62a	\N	\N	\N	42	2020-10-30 14:52:08.037202	2020-10-30 14:51:49.107817	172.25.0.1	172.25.0.1	2020-10-29 13:32:54.385677	2020-10-30 14:52:08.037789		\N	f	43afbeb0-d11a-40de-8d24-d300c04348aa	always	3a2d56900c27fd063d9556e5e9912eeb	DataCycleCore::User	\N	de	\N	\N	\N	\N	\N	\N	2020-10-28 13:32:54.228651	\N	\N
\.


--
-- TOC entry 4329 (class 0 OID 21328)
-- Dependencies: 218
-- Data for Name: watch_list_data_hashes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.watch_list_data_hashes (id, watch_list_id, hashable_id, hashable_type, seen_at, created_at, updated_at) FROM stdin;
6e47c4fa-0f0f-44d8-93a4-e7072b461d50	8e8b104c-eaa1-4c4e-a6a0-3643bdc112d2	030312f0-c8c3-45da-bd65-0674b50aaddc	DataCycleCore::Thing	\N	2020-10-30 13:29:31.944643	2020-10-30 13:29:31.944643
\.


--
-- TOC entry 4343 (class 0 OID 21860)
-- Dependencies: 233
-- Data for Name: watch_list_shares; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.watch_list_shares (id, shareable_id, watch_list_id, seen_at, created_at, updated_at, shareable_type) FROM stdin;
\.


--
-- TOC entry 4328 (class 0 OID 21319)
-- Dependencies: 217
-- Data for Name: watch_lists; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.watch_lists (id, name, user_id, seen_at, created_at, updated_at, full_path, full_path_names) FROM stdin;
8e8b104c-eaa1-4c4e-a6a0-3643bdc112d2	test	e123d2d0-a678-4a95-b447-be62ca039ddf	\N	2020-10-30 13:29:28.055951	2020-10-30 13:29:31.946695	test	{}
\.


--
-- TOC entry 4367 (class 0 OID 0)
-- Dependencies: 215
-- Name: delayed_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.delayed_jobs_id_seq', 5, true);


--
-- TOC entry 4168 (class 2606 OID 22041)
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- TOC entry 3992 (class 2606 OID 20988)
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- TOC entry 4115 (class 2606 OID 21723)
-- Name: asset_contents asset_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_contents
    ADD CONSTRAINT asset_contents_pkey PRIMARY KEY (id);


--
-- TOC entry 4106 (class 2606 OID 21701)
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- TOC entry 4096 (class 2606 OID 21631)
-- Name: classification_content_histories classification_content_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_content_histories
    ADD CONSTRAINT classification_content_histories_pkey PRIMARY KEY (id);


--
-- TOC entry 4090 (class 2606 OID 21622)
-- Name: classification_contents classification_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_contents
    ADD CONSTRAINT classification_contents_pkey PRIMARY KEY (id);


--
-- TOC entry 4182 (class 2606 OID 22122)
-- Name: classification_polygons classification_polygons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_polygons
    ADD CONSTRAINT classification_polygons_pkey PRIMARY KEY (id);


--
-- TOC entry 4001 (class 2606 OID 21016)
-- Name: classification_aliases classifications_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_aliases
    ADD CONSTRAINT classifications_aliases_pkey PRIMARY KEY (id);


--
-- TOC entry 4007 (class 2606 OID 21022)
-- Name: classification_groups classifications_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_groups
    ADD CONSTRAINT classifications_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 3994 (class 2606 OID 21006)
-- Name: classifications classifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classifications
    ADD CONSTRAINT classifications_pkey PRIMARY KEY (id);


--
-- TOC entry 4025 (class 2606 OID 21054)
-- Name: classification_tree_labels classifications_trees_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_tree_labels
    ADD CONSTRAINT classifications_trees_labels_pkey PRIMARY KEY (id);


--
-- TOC entry 4016 (class 2606 OID 21040)
-- Name: classification_trees classifications_trees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_trees
    ADD CONSTRAINT classifications_trees_pkey PRIMARY KEY (id);


--
-- TOC entry 4104 (class 2606 OID 21680)
-- Name: content_content_histories content_content_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_content_histories
    ADD CONSTRAINT content_content_histories_pkey PRIMARY KEY (id);


--
-- TOC entry 4100 (class 2606 OID 21669)
-- Name: content_contents content_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_contents
    ADD CONSTRAINT content_contents_pkey PRIMARY KEY (id);


--
-- TOC entry 4039 (class 2606 OID 21198)
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- TOC entry 4054 (class 2606 OID 21355)
-- Name: data_links edit_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_links
    ADD CONSTRAINT edit_links_pkey PRIMARY KEY (id);


--
-- TOC entry 4158 (class 2606 OID 21956)
-- Name: external_systems external_systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_systems
    ADD CONSTRAINT external_systems_pkey PRIMARY KEY (id);


--
-- TOC entry 4066 (class 2606 OID 21583)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 4179 (class 2606 OID 22102)
-- Name: schedule_histories schedule_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_histories
    ADD CONSTRAINT schedule_histories_pkey PRIMARY KEY (id);


--
-- TOC entry 4175 (class 2606 OID 22091)
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);


--
-- TOC entry 3990 (class 2606 OID 20980)
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- TOC entry 4086 (class 2606 OID 21613)
-- Name: searches searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searches
    ADD CONSTRAINT searches_pkey PRIMARY KEY (id);


--
-- TOC entry 4113 (class 2606 OID 21712)
-- Name: stored_filters stored_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stored_filters
    ADD CONSTRAINT stored_filters_pkey PRIMARY KEY (id);


--
-- TOC entry 4062 (class 2606 OID 21376)
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- TOC entry 4165 (class 2606 OID 22015)
-- Name: thing_duplicates thing_duplicates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_duplicates
    ADD CONSTRAINT thing_duplicates_pkey PRIMARY KEY (id);


--
-- TOC entry 4163 (class 2606 OID 21965)
-- Name: external_system_syncs thing_external_systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_syncs
    ADD CONSTRAINT thing_external_systems_pkey PRIMARY KEY (id);


--
-- TOC entry 4150 (class 2606 OID 21905)
-- Name: thing_histories thing_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_histories
    ADD CONSTRAINT thing_histories_pkey PRIMARY KEY (id);


--
-- TOC entry 4156 (class 2606 OID 21916)
-- Name: thing_history_translations thing_history_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_history_translations
    ADD CONSTRAINT thing_history_translations_pkey PRIMARY KEY (id);


--
-- TOC entry 4145 (class 2606 OID 21891)
-- Name: thing_translations thing_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_translations
    ADD CONSTRAINT thing_translations_pkey PRIMARY KEY (id);


--
-- TOC entry 4139 (class 2606 OID 21877)
-- Name: things things_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.things
    ADD CONSTRAINT things_pkey PRIMARY KEY (id);


--
-- TOC entry 4074 (class 2606 OID 21601)
-- Name: user_group_users user_group_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group_users
    ADD CONSTRAINT user_group_users_pkey PRIMARY KEY (id);


--
-- TOC entry 4070 (class 2606 OID 21594)
-- Name: user_groups user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_groups
    ADD CONSTRAINT user_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 4035 (class 2606 OID 21129)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4052 (class 2606 OID 21336)
-- Name: watch_list_data_hashes watch_list_data_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watch_list_data_hashes
    ADD CONSTRAINT watch_list_data_hashes_pkey PRIMARY KEY (id);


--
-- TOC entry 4121 (class 2606 OID 21865)
-- Name: watch_list_shares watch_list_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watch_list_shares
    ADD CONSTRAINT watch_list_user_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 4046 (class 2606 OID 21327)
-- Name: watch_lists watch_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watch_lists
    ADD CONSTRAINT watch_lists_pkey PRIMARY KEY (id);


--
-- TOC entry 4075 (class 1259 OID 21659)
-- Name: all_text_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX all_text_idx ON public.searches USING gin (all_text public.gin_trgm_ops);


--
-- TOC entry 4098 (class 1259 OID 21984)
-- Name: by_content_relation_a; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_content_relation_a ON public.content_contents USING btree (content_a_id, relation_a, content_b_id);


--
-- TOC entry 4122 (class 1259 OID 22129)
-- Name: by_created_by_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_created_by_created_at ON public.things USING btree (created_by, created_at);


--
-- TOC entry 4023 (class 1259 OID 21210)
-- Name: by_ctl_esi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_ctl_esi ON public.classification_tree_labels USING btree (external_source_id);


--
-- TOC entry 4160 (class 1259 OID 22141)
-- Name: by_external_connection_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_external_connection_and_type ON public.external_system_syncs USING btree (external_system_id, external_key, sync_type);


--
-- TOC entry 4123 (class 1259 OID 22130)
-- Name: by_template_name_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_template_name_template ON public.things USING btree (template_name, template);


--
-- TOC entry 4047 (class 1259 OID 22053)
-- Name: by_watch_list_hashable; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_watch_list_hashable ON public.watch_list_data_hashes USING btree (watch_list_id, hashable_id, hashable_type);


--
-- TOC entry 4014 (class 1259 OID 21041)
-- Name: child_parent_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX child_parent_index ON public.classification_trees USING btree (classification_alias_id, parent_classification_alias_id);


--
-- TOC entry 4094 (class 1259 OID 21833)
-- Name: classification_content_data_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_content_data_history_id_idx ON public.classification_content_histories USING btree (content_data_history_id);


--
-- TOC entry 4180 (class 1259 OID 22124)
-- Name: classification_polygons_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_polygons_geom_idx ON public.classification_polygons USING gist (geom);


--
-- TOC entry 4076 (class 1259 OID 21639)
-- Name: classification_string_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_string_idx ON public.searches USING gin (classification_string public.gin_trgm_ops);


--
-- TOC entry 4109 (class 1259 OID 21714)
-- Name: classified_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classified_name_idx ON public.stored_filters USING btree (api, system, name);


--
-- TOC entry 4102 (class 1259 OID 21682)
-- Name: content_b_history_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_b_history_idx ON public.content_content_histories USING btree (content_b_history_type, content_b_history_id);


--
-- TOC entry 4036 (class 1259 OID 21202)
-- Name: delayed_jobs_delayed_reference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_delayed_reference_id ON public.delayed_jobs USING btree (delayed_reference_id);


--
-- TOC entry 4037 (class 1259 OID 21203)
-- Name: delayed_jobs_delayed_reference_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_delayed_reference_type ON public.delayed_jobs USING btree (delayed_reference_type);


--
-- TOC entry 4040 (class 1259 OID 21200)
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_priority ON public.delayed_jobs USING btree (priority, run_at);


--
-- TOC entry 4041 (class 1259 OID 21201)
-- Name: delayed_jobs_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_queue ON public.delayed_jobs USING btree (queue);


--
-- TOC entry 4017 (class 1259 OID 21845)
-- Name: deleted_at_classification_alias_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_classification_alias_id_idx ON public.classification_trees USING btree (deleted_at, classification_alias_id);


--
-- TOC entry 4008 (class 1259 OID 21843)
-- Name: deleted_at_classification_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_classification_id_idx ON public.classification_groups USING btree (deleted_at, classification_id);


--
-- TOC entry 4002 (class 1259 OID 21844)
-- Name: deleted_at_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_id_idx ON public.classification_aliases USING btree (deleted_at, id);


--
-- TOC entry 3995 (class 1259 OID 21842)
-- Name: extid_extkey_del_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX extid_extkey_del_idx ON public.classifications USING btree (deleted_at, external_source_id, external_key);


--
-- TOC entry 4042 (class 1259 OID 22133)
-- Name: full_path_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX full_path_idx ON public.watch_lists USING gin (full_path public.gin_trgm_ops);


--
-- TOC entry 4077 (class 1259 OID 21640)
-- Name: headline_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX headline_idx ON public.searches USING gin (headline public.gin_trgm_ops);


--
-- TOC entry 4169 (class 1259 OID 22042)
-- Name: index_activities_on_activitiable_type_and_activitiable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activities_on_activitiable_type_and_activitiable_id ON public.activities USING btree (activitiable_type, activitiable_id);


--
-- TOC entry 4170 (class 1259 OID 22045)
-- Name: index_activities_on_activity_type_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activities_on_activity_type_and_updated_at ON public.activities USING btree (activity_type, updated_at);


--
-- TOC entry 4171 (class 1259 OID 22044)
-- Name: index_activities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activities_on_user_id ON public.activities USING btree (user_id);


--
-- TOC entry 4116 (class 1259 OID 21724)
-- Name: index_asset_contents_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_asset_contents_on_asset_id ON public.asset_contents USING btree (asset_id);


--
-- TOC entry 4117 (class 1259 OID 21725)
-- Name: index_asset_contents_on_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_asset_contents_on_content_data_id ON public.asset_contents USING btree (content_data_id);


--
-- TOC entry 4107 (class 1259 OID 22112)
-- Name: index_assets_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assets_on_creator_id ON public.assets USING btree (creator_id);


--
-- TOC entry 4108 (class 1259 OID 22113)
-- Name: index_assets_on_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assets_on_type ON public.assets USING btree (type);


--
-- TOC entry 4003 (class 1259 OID 21382)
-- Name: index_classification_aliases_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_aliases_on_deleted_at ON public.classification_aliases USING btree (deleted_at);


--
-- TOC entry 4004 (class 1259 OID 21205)
-- Name: index_classification_aliases_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_aliases_on_id ON public.classification_aliases USING btree (id);


--
-- TOC entry 4097 (class 1259 OID 21772)
-- Name: index_classification_content_histories_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_content_histories_on_classification_id ON public.classification_content_histories USING btree (classification_id);


--
-- TOC entry 4091 (class 1259 OID 21635)
-- Name: index_classification_contents_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_contents_on_classification_id ON public.classification_contents USING btree (classification_id);


--
-- TOC entry 4092 (class 1259 OID 21832)
-- Name: index_classification_contents_on_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_contents_on_content_data_id ON public.classification_contents USING btree (content_data_id);


--
-- TOC entry 4093 (class 1259 OID 22003)
-- Name: index_classification_contents_on_unique_constraint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_contents_on_unique_constraint ON public.classification_contents USING btree (content_data_id, classification_id, relation);


--
-- TOC entry 4009 (class 1259 OID 21207)
-- Name: index_classification_groups_on_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_classification_alias_id ON public.classification_groups USING btree (classification_alias_id);


--
-- TOC entry 4010 (class 1259 OID 21206)
-- Name: index_classification_groups_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_classification_id ON public.classification_groups USING btree (classification_id);


--
-- TOC entry 4011 (class 1259 OID 22052)
-- Name: index_classification_groups_on_classification_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_classification_id_and_created_at ON public.classification_groups USING btree (classification_id, created_at);


--
-- TOC entry 4012 (class 1259 OID 21383)
-- Name: index_classification_groups_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_deleted_at ON public.classification_groups USING btree (deleted_at);


--
-- TOC entry 4013 (class 1259 OID 21208)
-- Name: index_classification_groups_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_external_source_id ON public.classification_groups USING btree (external_source_id);


--
-- TOC entry 4026 (class 1259 OID 21386)
-- Name: index_classification_tree_labels_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_tree_labels_on_deleted_at ON public.classification_tree_labels USING btree (deleted_at);


--
-- TOC entry 4027 (class 1259 OID 21209)
-- Name: index_classification_tree_labels_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_tree_labels_on_id ON public.classification_tree_labels USING btree (id);


--
-- TOC entry 4028 (class 1259 OID 22049)
-- Name: index_classification_tree_labels_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_tree_labels_on_name ON public.classification_tree_labels USING btree (name);


--
-- TOC entry 4018 (class 1259 OID 21042)
-- Name: index_classification_trees_on_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_classification_alias_id ON public.classification_trees USING btree (classification_alias_id);


--
-- TOC entry 4019 (class 1259 OID 22050)
-- Name: index_classification_trees_on_classification_tree_label_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_classification_tree_label_id ON public.classification_trees USING btree (classification_tree_label_id);


--
-- TOC entry 4020 (class 1259 OID 21385)
-- Name: index_classification_trees_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_deleted_at ON public.classification_trees USING btree (deleted_at);


--
-- TOC entry 4021 (class 1259 OID 21045)
-- Name: index_classification_trees_on_parent_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_parent_classification_alias_id ON public.classification_trees USING btree (parent_classification_alias_id);


--
-- TOC entry 3996 (class 1259 OID 21381)
-- Name: index_classifications_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_on_deleted_at ON public.classifications USING btree (deleted_at);


--
-- TOC entry 3997 (class 1259 OID 22126)
-- Name: index_classifications_on_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_on_external_key ON public.classifications USING btree (external_key);


--
-- TOC entry 3998 (class 1259 OID 21212)
-- Name: index_classifications_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_on_external_source_id ON public.classifications USING btree (external_source_id);


--
-- TOC entry 3999 (class 1259 OID 21211)
-- Name: index_classifications_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classifications_on_id ON public.classifications USING btree (id);


--
-- TOC entry 4101 (class 1259 OID 22048)
-- Name: index_content_contents_on_content_b_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_content_contents_on_content_b_id ON public.content_contents USING btree (content_b_id);


--
-- TOC entry 4055 (class 1259 OID 21791)
-- Name: index_data_links_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_asset_id ON public.data_links USING btree (asset_id);


--
-- TOC entry 4056 (class 1259 OID 21356)
-- Name: index_data_links_on_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_item_id ON public.data_links USING btree (item_id);


--
-- TOC entry 4057 (class 1259 OID 21357)
-- Name: index_data_links_on_item_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_item_type ON public.data_links USING btree (item_type);


--
-- TOC entry 4161 (class 1259 OID 22136)
-- Name: index_external_system_syncs_on_unique_attributes; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_system_syncs_on_unique_attributes ON public.external_system_syncs USING btree (syncable_type, syncable_id, external_system_id, sync_type, external_key);


--
-- TOC entry 4159 (class 1259 OID 21966)
-- Name: index_external_systems_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_systems_on_id ON public.external_systems USING btree (id);


--
-- TOC entry 4063 (class 1259 OID 21584)
-- Name: index_roles_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_name ON public.roles USING btree (name);


--
-- TOC entry 4064 (class 1259 OID 21585)
-- Name: index_roles_on_rank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_rank ON public.roles USING btree (rank);


--
-- TOC entry 4176 (class 1259 OID 22105)
-- Name: index_schedule_histories_on_from_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_histories_on_from_to ON public.schedule_histories USING gist (tstzrange(dtstart, dtend, '[]'::text));


--
-- TOC entry 4177 (class 1259 OID 22107)
-- Name: index_schedule_histories_on_thing_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_histories_on_thing_history_id ON public.schedule_histories USING btree (thing_history_id);


--
-- TOC entry 4172 (class 1259 OID 22104)
-- Name: index_schedules_on_from_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedules_on_from_to ON public.schedules USING gist (tstzrange(dtstart, dtend, '[]'::text));


--
-- TOC entry 4173 (class 1259 OID 22106)
-- Name: index_schedules_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedules_on_thing_id ON public.schedules USING btree (thing_id);


--
-- TOC entry 4078 (class 1259 OID 22054)
-- Name: index_searches_on_advanced_attributes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_advanced_attributes ON public.searches USING gin (advanced_attributes);


--
-- TOC entry 4079 (class 1259 OID 22110)
-- Name: index_searches_on_classification_aliases_mapping; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_classification_aliases_mapping ON public.searches USING gin (classification_aliases_mapping);


--
-- TOC entry 4080 (class 1259 OID 22111)
-- Name: index_searches_on_classification_ancestors_mapping; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_classification_ancestors_mapping ON public.searches USING gin (classification_ancestors_mapping);


--
-- TOC entry 4081 (class 1259 OID 21835)
-- Name: index_searches_on_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_content_data_id ON public.searches USING btree (content_data_id);


--
-- TOC entry 4082 (class 1259 OID 21969)
-- Name: index_searches_on_content_data_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_searches_on_content_data_id_and_locale ON public.searches USING btree (content_data_id, locale);


--
-- TOC entry 4083 (class 1259 OID 21834)
-- Name: index_searches_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_locale ON public.searches USING btree (locale);


--
-- TOC entry 4084 (class 1259 OID 21634)
-- Name: index_searches_on_words; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_words ON public.searches USING gin (words);


--
-- TOC entry 4110 (class 1259 OID 21987)
-- Name: index_stored_filters_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stored_filters_on_updated_at ON public.stored_filters USING btree (updated_at);


--
-- TOC entry 4111 (class 1259 OID 21713)
-- Name: index_stored_filters_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stored_filters_on_user_id ON public.stored_filters USING btree (user_id);


--
-- TOC entry 4058 (class 1259 OID 21378)
-- Name: index_subscriptions_on_subscribable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_subscribable_id ON public.subscriptions USING btree (subscribable_id);


--
-- TOC entry 4059 (class 1259 OID 21379)
-- Name: index_subscriptions_on_subscribable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_subscribable_type ON public.subscriptions USING btree (subscribable_type);


--
-- TOC entry 4060 (class 1259 OID 21377)
-- Name: index_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_user_id ON public.subscriptions USING btree (user_id);


--
-- TOC entry 4146 (class 1259 OID 21906)
-- Name: index_thing_histories_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_histories_on_id ON public.thing_histories USING btree (id);


--
-- TOC entry 4147 (class 1259 OID 22030)
-- Name: index_thing_histories_on_representation_of_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_histories_on_representation_of_id ON public.thing_histories USING btree (representation_of_id);


--
-- TOC entry 4148 (class 1259 OID 21907)
-- Name: index_thing_histories_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_histories_on_thing_id ON public.thing_histories USING btree (thing_id);


--
-- TOC entry 4151 (class 1259 OID 21918)
-- Name: index_thing_history_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_id_locale ON public.thing_history_translations USING btree (thing_history_id, locale);


--
-- TOC entry 4152 (class 1259 OID 21917)
-- Name: index_thing_history_translations_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_history_translations_on_id ON public.thing_history_translations USING btree (id);


--
-- TOC entry 4153 (class 1259 OID 21920)
-- Name: index_thing_history_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_translations_on_locale ON public.thing_history_translations USING btree (locale);


--
-- TOC entry 4154 (class 1259 OID 21919)
-- Name: index_thing_history_translations_on_thing_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_translations_on_thing_history_id ON public.thing_history_translations USING btree (thing_history_id);


--
-- TOC entry 4140 (class 1259 OID 21893)
-- Name: index_thing_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_id_locale ON public.thing_translations USING btree (thing_id, locale);


--
-- TOC entry 4141 (class 1259 OID 21892)
-- Name: index_thing_translations_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_translations_on_id ON public.thing_translations USING btree (id);


--
-- TOC entry 4142 (class 1259 OID 21895)
-- Name: index_thing_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_translations_on_locale ON public.thing_translations USING btree (locale);


--
-- TOC entry 4143 (class 1259 OID 21894)
-- Name: index_thing_translations_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_translations_on_thing_id ON public.thing_translations USING btree (thing_id);


--
-- TOC entry 4124 (class 1259 OID 21989)
-- Name: index_things_on_boost_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_boost_updated_at ON public.things USING btree (boost, updated_at);


--
-- TOC entry 4125 (class 1259 OID 22134)
-- Name: index_things_on_boost_updated_at_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_boost_updated_at_id ON public.things USING btree (boost, updated_at, id);


--
-- TOC entry 4126 (class 1259 OID 21922)
-- Name: index_things_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_content_type ON public.things USING btree (((schema ->> 'content_type'::text)));


--
-- TOC entry 4127 (class 1259 OID 21880)
-- Name: index_things_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_external_source_id ON public.things USING btree (external_source_id);


--
-- TOC entry 4128 (class 1259 OID 21882)
-- Name: index_things_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_things_on_external_source_id_and_external_key ON public.things USING btree (external_source_id, external_key);


--
-- TOC entry 4129 (class 1259 OID 21878)
-- Name: index_things_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_things_on_id ON public.things USING btree (id);


--
-- TOC entry 4130 (class 1259 OID 22051)
-- Name: index_things_on_is_part_of; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_is_part_of ON public.things USING btree (is_part_of);


--
-- TOC entry 4131 (class 1259 OID 22127)
-- Name: index_things_on_location_geography_cast; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_location_geography_cast ON public.things USING gist (public.geography(location));


--
-- TOC entry 4132 (class 1259 OID 22125)
-- Name: index_things_on_location_spatial; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_location_spatial ON public.things USING gist (location);


--
-- TOC entry 4133 (class 1259 OID 22029)
-- Name: index_things_on_representation_of_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_representation_of_id ON public.things USING btree (representation_of_id);


--
-- TOC entry 4134 (class 1259 OID 21988)
-- Name: index_things_on_schema_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_schema_type ON public.things USING btree (((schema ->> 'schema_type'::text)));


--
-- TOC entry 4135 (class 1259 OID 22109)
-- Name: index_things_on_template_content_type_validity_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_template_content_type_validity_range ON public.things USING btree (id, template, content_type, validity_range, template_name);


--
-- TOC entry 4136 (class 1259 OID 21879)
-- Name: index_things_template_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_template_template_name_idx ON public.things USING btree (template, template_name);


--
-- TOC entry 4071 (class 1259 OID 21602)
-- Name: index_user_group_users_on_user_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_group_users_on_user_group_id ON public.user_group_users USING btree (user_group_id);


--
-- TOC entry 4072 (class 1259 OID 21603)
-- Name: index_user_group_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_group_users_on_user_id ON public.user_group_users USING btree (user_id);


--
-- TOC entry 4067 (class 1259 OID 21839)
-- Name: index_user_groups_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_groups_on_id ON public.user_groups USING btree (id);


--
-- TOC entry 4068 (class 1259 OID 21595)
-- Name: index_user_groups_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_groups_on_name ON public.user_groups USING btree (name);


--
-- TOC entry 4029 (class 1259 OID 22046)
-- Name: index_users_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_creator_id ON public.users USING btree (creator_id);


--
-- TOC entry 4030 (class 1259 OID 21130)
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- TOC entry 4031 (class 1259 OID 21232)
-- Name: index_users_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_id ON public.users USING btree (id);


--
-- TOC entry 4032 (class 1259 OID 22047)
-- Name: index_users_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_jti ON public.users USING btree (jti);


--
-- TOC entry 4033 (class 1259 OID 21132)
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- TOC entry 4137 (class 1259 OID 21986)
-- Name: index_validity_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_validity_range ON public.things USING gist (validity_range);


--
-- TOC entry 4048 (class 1259 OID 21343)
-- Name: index_watch_list_data_hashes_on_hashable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_hashable_id ON public.watch_list_data_hashes USING btree (hashable_id);


--
-- TOC entry 4049 (class 1259 OID 21344)
-- Name: index_watch_list_data_hashes_on_hashable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_hashable_type ON public.watch_list_data_hashes USING btree (hashable_type);


--
-- TOC entry 4050 (class 1259 OID 21337)
-- Name: index_watch_list_data_hashes_on_watch_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_watch_list_id ON public.watch_list_data_hashes USING btree (watch_list_id);


--
-- TOC entry 4118 (class 1259 OID 21867)
-- Name: index_watch_list_shares_on_watch_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_shares_on_watch_list_id ON public.watch_list_shares USING btree (watch_list_id);


--
-- TOC entry 4043 (class 1259 OID 21837)
-- Name: index_watch_lists_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_lists_on_id ON public.watch_lists USING btree (id);


--
-- TOC entry 4044 (class 1259 OID 21838)
-- Name: index_watch_lists_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_lists_on_user_id ON public.watch_lists USING btree (user_id);


--
-- TOC entry 4005 (class 1259 OID 21633)
-- Name: name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX name_idx ON public.classification_aliases USING gin (internal_name public.gin_trgm_ops);


--
-- TOC entry 4022 (class 1259 OID 21043)
-- Name: parent_child_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX parent_child_index ON public.classification_trees USING btree (parent_classification_alias_id, classification_alias_id);


--
-- TOC entry 4119 (class 1259 OID 22027)
-- Name: unique_by_shareable; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_by_shareable ON public.watch_list_shares USING btree (shareable_id, shareable_type, watch_list_id);


--
-- TOC entry 4166 (class 1259 OID 22017)
-- Name: unique_duplicate_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_duplicate_index ON public.thing_duplicates USING btree (thing_id, thing_duplicate_id, method);


--
-- TOC entry 4087 (class 1259 OID 21658)
-- Name: validity_period_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX validity_period_idx ON public.searches USING gist (validity_period);


--
-- TOC entry 4088 (class 1259 OID 21632)
-- Name: words_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_idx ON public.searches USING gin (full_text public.gin_trgm_ops);


--
-- TOC entry 4183 (class 2620 OID 22103)
-- Name: searches tsvectorsearchupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsvectorsearchupdate BEFORE INSERT OR UPDATE ON public.searches FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('words', 'pg_catalog.simple', 'full_text');


-- Completed on 2020-10-30 16:01:53 CET

--
-- PostgreSQL database dump complete
--

