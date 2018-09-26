SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: asset_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE asset_contents (
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

CREATE TABLE assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    file character varying,
    type character varying,
    content_type character varying,
    file_size integer,
    creator_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    seen_at timestamp without time zone,
    name character varying
);


--
-- Name: classification_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classification_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    internal boolean DEFAULT false,
    deleted_at timestamp without time zone,
    assignable boolean DEFAULT true,
    description character varying
);


--
-- Name: classification_tree_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classification_tree_labels (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    internal boolean DEFAULT false,
    deleted_at timestamp without time zone
);


--
-- Name: classification_trees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classification_trees (
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
-- Name: classification_alias_paths; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW classification_alias_paths AS
 WITH RECURSIVE classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names) AS (
         SELECT classification_aliases.id,
            ARRAY[]::uuid[] AS ancestor_ids,
            ARRAY[classification_aliases.id] AS full_path_ids,
            ARRAY[classification_aliases.name, classification_tree_labels.name] AS full_path_names
           FROM ((classification_trees
             JOIN classification_aliases ON ((classification_aliases.id = classification_trees.classification_alias_id)))
             JOIN classification_tree_labels ON ((classification_tree_labels.id = classification_trees.classification_tree_label_id)))
          WHERE (classification_trees.parent_classification_alias_id IS NULL)
        UNION ALL
         SELECT classification_aliases.id,
            (classification_alias_paths_1.id || classification_alias_paths_1.ancestor_ids) AS ancestor_ids,
            (classification_aliases.id || classification_alias_paths_1.full_path_ids) AS full_path_ids,
            (classification_aliases.name || classification_alias_paths_1.full_path_names) AS full_path_names
           FROM ((classification_trees
             JOIN classification_alias_paths classification_alias_paths_1 ON ((classification_alias_paths_1.id = classification_trees.parent_classification_alias_id)))
             JOIN classification_aliases ON ((classification_aliases.id = classification_trees.classification_alias_id)))
        )
 SELECT classification_alias_paths.id,
    classification_alias_paths.ancestor_ids,
    classification_alias_paths.full_path_ids,
    classification_alias_paths.full_path_names
   FROM classification_alias_paths;


--
-- Name: classification_content_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classification_content_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_data_history_id uuid,
    content_data_history_type character varying,
    classification_id uuid,
    tag boolean,
    classification boolean,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    relation character varying
);


--
-- Name: classification_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classification_contents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_data_id uuid,
    content_data_type character varying,
    classification_id uuid,
    tag boolean,
    classification boolean,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    relation character varying
);


--
-- Name: classification_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classification_groups (
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
-- Name: classifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    external_source_id uuid,
    external_key character varying,
    description character varying,
    seen_at timestamp without time zone,
    location geometry(Point,4326),
    bbox geometry(Polygon,4326),
    shape geometry(MultiPolygon,4326),
    external_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- Name: content_content_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_content_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_a_history_id uuid,
    content_a_history_type character varying,
    relation_a character varying,
    content_b_history_id uuid,
    content_b_history_type character varying,
    relation_b character varying,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    order_a integer,
    order_b integer
);


--
-- Name: content_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_contents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_a_id uuid,
    content_a_type character varying,
    relation_a character varying,
    content_b_id uuid,
    content_b_type character varying,
    relation_b character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    order_a integer,
    order_b integer
);


--
-- Name: data_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE data_links (
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
    asset_id uuid
);


--
-- Name: watch_list_data_hashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE watch_list_data_hashes (
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

CREATE VIEW content_items AS
 SELECT data_links.id AS data_link_id,
    watch_list_data_hashes.hashable_type AS content_type,
    watch_list_data_hashes.hashable_id AS content_id,
    data_links.creator_id,
    data_links.receiver_id
   FROM (data_links
     JOIN watch_list_data_hashes ON ((watch_list_data_hashes.watch_list_id = data_links.item_id)))
  WHERE ((data_links.item_type)::text = 'DataCycleCore::WatchList'::text)
UNION
 SELECT data_links.id AS data_link_id,
    data_links.item_type AS content_type,
    data_links.item_id AS content_id,
    data_links.creator_id,
    data_links.receiver_id
   FROM data_links
  WHERE ((data_links.item_type)::text <> 'DataCycleCore::WatchList'::text);


--
-- Name: creative_works; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE creative_works (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "position" integer DEFAULT 0,
    is_part_of uuid,
    metadata jsonb,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    template boolean DEFAULT false NOT NULL,
    external_key character varying,
    template_name character varying,
    schema jsonb,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    deleted_at timestamp without time zone
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    metadata jsonb,
    template boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    external_key character varying,
    template_name character varying,
    schema jsonb,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    deleted_at timestamp without time zone
);


--
-- Name: persons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE persons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    given_name character varying,
    family_name character varying,
    metadata jsonb,
    template boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid,
    external_key character varying,
    template_name character varying,
    schema jsonb,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    deleted_at timestamp without time zone
);


--
-- Name: places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE places (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_source_id uuid,
    external_key character varying,
    longitude double precision,
    latitude double precision,
    elevation double precision,
    location geometry(Point,4326),
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    photo uuid,
    line geography(LineStringZ,4326),
    metadata jsonb,
    template boolean DEFAULT false,
    address_locality character varying,
    street_address character varying,
    postal_code character varying,
    address_country character varying,
    fax_number character varying,
    telephone character varying,
    email character varying,
    template_name character varying,
    schema jsonb,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    deleted_at timestamp without time zone
);


--
-- Name: things; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE things (
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
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- Name: content_meta_items; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW content_meta_items AS
 SELECT creative_works.id,
    'DataCycleCore::CreativeWork'::text AS content_type,
    creative_works.template_name,
    creative_works.schema,
    creative_works.external_source_id,
    creative_works.external_key,
    creative_works.created_by,
    creative_works.updated_by,
    creative_works.deleted_by
   FROM creative_works
  WHERE (creative_works.template IS FALSE)
UNION
 SELECT events.id,
    'DataCycleCore::Event'::text AS content_type,
    events.template_name,
    events.schema,
    events.external_source_id,
    events.external_key,
    events.created_by,
    events.updated_by,
    events.deleted_by
   FROM events
  WHERE (events.template IS FALSE)
UNION
 SELECT persons.id,
    'DataCycleCore::Person'::text AS content_type,
    persons.template_name,
    persons.schema,
    persons.external_source_id,
    persons.external_key,
    persons.created_by,
    persons.updated_by,
    persons.deleted_by
   FROM persons
  WHERE (persons.template IS FALSE)
UNION
 SELECT places.id,
    'DataCycleCore::Place'::text AS content_type,
    places.template_name,
    places.schema,
    places.external_source_id,
    places.external_key,
    places.created_by,
    places.updated_by,
    places.deleted_by
   FROM places
  WHERE (places.template IS FALSE)
UNION
 SELECT things.id,
    'DataCycleCore::Thing'::text AS content_type,
    things.template_name,
    things.schema,
    things.external_source_id,
    things.external_key,
    things.created_by,
    things.updated_by,
    things.deleted_by
   FROM things
  WHERE (things.template IS FALSE);


--
-- Name: creative_work_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE creative_work_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    creative_work_id uuid,
    "position" integer,
    is_part_of uuid,
    metadata jsonb,
    template boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    external_source_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_key character varying,
    deleted_at timestamp without time zone,
    template_name character varying,
    schema jsonb,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid
);


--
-- Name: creative_work_history_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE creative_work_history_translations (
    id integer NOT NULL,
    creative_work_history_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    headline text,
    description text,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: creative_work_history_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE creative_work_history_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: creative_work_history_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE creative_work_history_translations_id_seq OWNED BY creative_work_history_translations.id;


--
-- Name: creative_work_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE creative_work_translations (
    id integer NOT NULL,
    creative_work_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    headline text,
    description text
);


--
-- Name: creative_work_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE creative_work_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: creative_work_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE creative_work_translations_id_seq OWNED BY creative_work_translations.id;


--
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE delayed_jobs (
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

CREATE SEQUENCE delayed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE delayed_jobs_id_seq OWNED BY delayed_jobs.id;


--
-- Name: event_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE event_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    metadata jsonb,
    template boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    external_source_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_key character varying,
    deleted_at timestamp without time zone,
    template_name character varying,
    schema jsonb,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid
);


--
-- Name: event_history_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE event_history_translations (
    id integer NOT NULL,
    event_history_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    headline text,
    description text,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: event_history_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE event_history_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_history_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE event_history_translations_id_seq OWNED BY event_history_translations.id;


--
-- Name: event_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE event_translations (
    id integer NOT NULL,
    event_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    headline text,
    description text
);


--
-- Name: event_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE event_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE event_translations_id_seq OWNED BY event_translations.id;


--
-- Name: external_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE external_sources (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    credentials jsonb,
    config jsonb,
    last_download timestamp without time zone,
    last_import timestamp without time zone,
    default_options jsonb
);


--
-- Name: organization_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE organization_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    metadata jsonb,
    template boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    template_name character varying,
    schema jsonb,
    external_source_id uuid,
    external_key character varying,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid
);


--
-- Name: organization_history_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE organization_history_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_history_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    headline character varying,
    description text,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: organization_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE organization_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    headline character varying,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    metadata jsonb,
    template boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    template_name character varying,
    schema jsonb,
    external_source_id uuid,
    external_key character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid,
    deleted_at timestamp without time zone
);


--
-- Name: person_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE person_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    person_id uuid,
    given_name character varying,
    family_name character varying,
    metadata jsonb,
    template boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    external_source_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_key character varying,
    deleted_at timestamp without time zone,
    template_name character varying,
    schema jsonb,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid
);


--
-- Name: person_history_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE person_history_translations (
    id integer NOT NULL,
    person_history_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    headline text,
    description text,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: person_history_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE person_history_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_history_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE person_history_translations_id_seq OWNED BY person_history_translations.id;


--
-- Name: person_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE person_translations (
    id integer NOT NULL,
    person_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    headline text,
    description text
);


--
-- Name: person_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE person_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE person_translations_id_seq OWNED BY person_translations.id;


--
-- Name: place_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE place_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    place_id uuid,
    external_key character varying,
    longitude double precision,
    latitude double precision,
    elevation double precision,
    location geometry(Point,4326),
    line geography(LineStringZ,4326),
    photo uuid,
    metadata jsonb,
    template boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    external_source_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    address_locality character varying,
    street_address character varying,
    postal_code character varying,
    address_country character varying,
    fax_number character varying,
    telephone character varying,
    email character varying,
    deleted_at timestamp without time zone,
    template_name character varying,
    schema jsonb,
    created_by uuid,
    updated_by uuid,
    deleted_by uuid
);


--
-- Name: place_history_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE place_history_translations (
    id integer NOT NULL,
    place_history_id uuid NOT NULL,
    locale character varying NOT NULL,
    name character varying,
    url character varying,
    hours_available character varying,
    address character varying,
    content jsonb,
    headline text,
    description text,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: place_history_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE place_history_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: place_history_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE place_history_translations_id_seq OWNED BY place_history_translations.id;


--
-- Name: place_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE place_translations (
    id integer NOT NULL,
    place_id uuid NOT NULL,
    locale character varying NOT NULL,
    name character varying,
    url character varying,
    hours_available character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    content jsonb,
    description text,
    headline text
);


--
-- Name: place_translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE place_translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: place_translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE place_translations_id_seq OWNED BY place_translations.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    rank integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE searches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_data_id uuid,
    content_data_type character varying,
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
    schema_type character varying DEFAULT 'Thing'::character varying NOT NULL
);


--
-- Name: stored_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE stored_filters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    user_id uuid,
    language character varying[],
    parameters jsonb,
    system boolean DEFAULT false,
    api boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    api_users text[]
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE subscriptions (
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

CREATE TABLE thing_histories (
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
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- Name: thing_history_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE thing_history_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_history_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    name character varying,
    description text,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: thing_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE thing_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_id uuid NOT NULL,
    locale character varying NOT NULL,
    content jsonb,
    name character varying,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: use_cases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE use_cases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    external_source_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_group_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE user_group_users (
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

CREATE TABLE user_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE users (
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
    type character varying,
    name character varying,
    default_locale character varying DEFAULT 'de'::character varying
);


--
-- Name: watch_list_user_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE watch_list_user_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_group_id uuid,
    watch_list_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: watch_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE watch_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    headline character varying,
    user_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: creative_work_history_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY creative_work_history_translations ALTER COLUMN id SET DEFAULT nextval('creative_work_history_translations_id_seq'::regclass);


--
-- Name: creative_work_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY creative_work_translations ALTER COLUMN id SET DEFAULT nextval('creative_work_translations_id_seq'::regclass);


--
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY delayed_jobs ALTER COLUMN id SET DEFAULT nextval('delayed_jobs_id_seq'::regclass);


--
-- Name: event_history_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY event_history_translations ALTER COLUMN id SET DEFAULT nextval('event_history_translations_id_seq'::regclass);


--
-- Name: event_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY event_translations ALTER COLUMN id SET DEFAULT nextval('event_translations_id_seq'::regclass);


--
-- Name: person_history_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY person_history_translations ALTER COLUMN id SET DEFAULT nextval('person_history_translations_id_seq'::regclass);


--
-- Name: person_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY person_translations ALTER COLUMN id SET DEFAULT nextval('person_translations_id_seq'::regclass);


--
-- Name: place_history_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY place_history_translations ALTER COLUMN id SET DEFAULT nextval('place_history_translations_id_seq'::regclass);


--
-- Name: place_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY place_translations ALTER COLUMN id SET DEFAULT nextval('place_translations_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: asset_contents asset_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY asset_contents
    ADD CONSTRAINT asset_contents_pkey PRIMARY KEY (id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: classification_content_histories classification_content_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classification_content_histories
    ADD CONSTRAINT classification_content_histories_pkey PRIMARY KEY (id);


--
-- Name: classification_contents classification_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classification_contents
    ADD CONSTRAINT classification_contents_pkey PRIMARY KEY (id);


--
-- Name: classification_aliases classifications_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classification_aliases
    ADD CONSTRAINT classifications_aliases_pkey PRIMARY KEY (id);


--
-- Name: classification_groups classifications_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classification_groups
    ADD CONSTRAINT classifications_groups_pkey PRIMARY KEY (id);


--
-- Name: classifications classifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classifications
    ADD CONSTRAINT classifications_pkey PRIMARY KEY (id);


--
-- Name: classification_tree_labels classifications_trees_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classification_tree_labels
    ADD CONSTRAINT classifications_trees_labels_pkey PRIMARY KEY (id);


--
-- Name: classification_trees classifications_trees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classification_trees
    ADD CONSTRAINT classifications_trees_pkey PRIMARY KEY (id);


--
-- Name: content_content_histories content_content_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_content_histories
    ADD CONSTRAINT content_content_histories_pkey PRIMARY KEY (id);


--
-- Name: content_contents content_contents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_contents
    ADD CONSTRAINT content_contents_pkey PRIMARY KEY (id);


--
-- Name: creative_work_histories creative_work_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY creative_work_histories
    ADD CONSTRAINT creative_work_histories_pkey PRIMARY KEY (id);


--
-- Name: creative_work_history_translations creative_work_history_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY creative_work_history_translations
    ADD CONSTRAINT creative_work_history_translations_pkey PRIMARY KEY (id);


--
-- Name: creative_work_translations creative_work_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY creative_work_translations
    ADD CONSTRAINT creative_work_translations_pkey PRIMARY KEY (id);


--
-- Name: creative_works creative_works_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY creative_works
    ADD CONSTRAINT creative_works_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: data_links edit_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY data_links
    ADD CONSTRAINT edit_links_pkey PRIMARY KEY (id);


--
-- Name: event_histories event_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY event_histories
    ADD CONSTRAINT event_histories_pkey PRIMARY KEY (id);


--
-- Name: event_history_translations event_history_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY event_history_translations
    ADD CONSTRAINT event_history_translations_pkey PRIMARY KEY (id);


--
-- Name: event_translations event_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY event_translations
    ADD CONSTRAINT event_translations_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: external_sources external_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY external_sources
    ADD CONSTRAINT external_sources_pkey PRIMARY KEY (id);


--
-- Name: organization_histories organization_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization_histories
    ADD CONSTRAINT organization_histories_pkey PRIMARY KEY (id);


--
-- Name: organization_history_translations organization_history_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization_history_translations
    ADD CONSTRAINT organization_history_translations_pkey PRIMARY KEY (id);


--
-- Name: organization_translations organization_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization_translations
    ADD CONSTRAINT organization_translations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: person_histories person_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY person_histories
    ADD CONSTRAINT person_histories_pkey PRIMARY KEY (id);


--
-- Name: person_history_translations person_history_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY person_history_translations
    ADD CONSTRAINT person_history_translations_pkey PRIMARY KEY (id);


--
-- Name: person_translations person_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY person_translations
    ADD CONSTRAINT person_translations_pkey PRIMARY KEY (id);


--
-- Name: persons persons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY persons
    ADD CONSTRAINT persons_pkey PRIMARY KEY (id);


--
-- Name: place_histories place_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY place_histories
    ADD CONSTRAINT place_histories_pkey PRIMARY KEY (id);


--
-- Name: place_history_translations place_history_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY place_history_translations
    ADD CONSTRAINT place_history_translations_pkey PRIMARY KEY (id);


--
-- Name: place_translations place_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY place_translations
    ADD CONSTRAINT place_translations_pkey PRIMARY KEY (id);


--
-- Name: places places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY places
    ADD CONSTRAINT places_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: searches searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY searches
    ADD CONSTRAINT searches_pkey PRIMARY KEY (id);


--
-- Name: stored_filters stored_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stored_filters
    ADD CONSTRAINT stored_filters_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: thing_histories thing_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY thing_histories
    ADD CONSTRAINT thing_histories_pkey PRIMARY KEY (id);


--
-- Name: thing_history_translations thing_history_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY thing_history_translations
    ADD CONSTRAINT thing_history_translations_pkey PRIMARY KEY (id);


--
-- Name: thing_translations thing_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY thing_translations
    ADD CONSTRAINT thing_translations_pkey PRIMARY KEY (id);


--
-- Name: things things_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY things
    ADD CONSTRAINT things_pkey PRIMARY KEY (id);


--
-- Name: use_cases use_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY use_cases
    ADD CONSTRAINT use_cases_pkey PRIMARY KEY (id);


--
-- Name: user_group_users user_group_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_group_users
    ADD CONSTRAINT user_group_users_pkey PRIMARY KEY (id);


--
-- Name: user_groups user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_groups
    ADD CONSTRAINT user_groups_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: watch_list_data_hashes watch_list_data_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY watch_list_data_hashes
    ADD CONSTRAINT watch_list_data_hashes_pkey PRIMARY KEY (id);


--
-- Name: watch_list_user_groups watch_list_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY watch_list_user_groups
    ADD CONSTRAINT watch_list_user_groups_pkey PRIMARY KEY (id);


--
-- Name: watch_lists watch_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY watch_lists
    ADD CONSTRAINT watch_lists_pkey PRIMARY KEY (id);


--
-- Name: all_text_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX all_text_idx ON searches USING gin (all_text gin_trgm_ops);


--
-- Name: by_content_data_classification_relation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_content_data_classification_relation ON classification_contents USING btree (content_data_id, content_data_type, classification_id, relation);


--
-- Name: by_content_data_history_classification_relation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_content_data_history_classification_relation ON classification_content_histories USING btree (content_data_history_id, content_data_history_type, classification_id, relation);


--
-- Name: by_content_data_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_content_data_locale ON searches USING btree (content_data_id, content_data_type, locale);


--
-- Name: by_ctl_esi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_ctl_esi ON classification_tree_labels USING btree (external_source_id);


--
-- Name: by_cwt_cwi_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_cwt_cwi_locale ON creative_work_translations USING btree (creative_work_id, locale);


--
-- Name: by_et_ei_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_et_ei_locale ON event_translations USING btree (event_id, locale);


--
-- Name: by_ot_ei_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_ot_ei_locale ON organization_translations USING btree (organization_id, locale);


--
-- Name: by_persont_pi_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_persont_pi_locale ON person_translations USING btree (person_id, locale);


--
-- Name: by_pt_p_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_pt_p_locale ON place_translations USING btree (place_id, locale);


--
-- Name: child_parent_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX child_parent_index ON classification_trees USING btree (classification_alias_id, parent_classification_alias_id);


--
-- Name: classification_content_data_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_content_data_history_id_idx ON classification_content_histories USING btree (content_data_history_id);


--
-- Name: classification_content_data_history_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_content_data_history_idx ON classification_content_histories USING btree (content_data_history_type, content_data_history_id);


--
-- Name: classification_content_data_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_content_data_idx ON classification_contents USING btree (content_data_type, content_data_id);


--
-- Name: classification_string_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_string_idx ON searches USING gin (classification_string gin_trgm_ops);


--
-- Name: classified_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classified_name_idx ON stored_filters USING btree (api, system, name);


--
-- Name: content_a_history_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_a_history_idx ON content_content_histories USING btree (content_a_history_type, content_a_history_id);


--
-- Name: content_a_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_a_idx ON content_contents USING btree (content_a_type, content_a_id);


--
-- Name: content_b_history_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_b_history_idx ON content_content_histories USING btree (content_b_history_type, content_b_history_id);


--
-- Name: content_b_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_b_idx ON content_contents USING btree (content_b_type, content_b_id);


--
-- Name: creative_work_histories_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX creative_work_histories_id_idx ON creative_work_histories USING btree (id);


--
-- Name: creative_work_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX creative_work_history_id_idx ON creative_work_history_translations USING btree (creative_work_history_id);


--
-- Name: creative_work_history_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX creative_work_history_locale_idx ON creative_work_history_translations USING btree (locale);


--
-- Name: creative_work_id_foreign_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX creative_work_id_foreign_key_idx ON creative_work_histories USING btree (creative_work_id);


--
-- Name: creative_work_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX creative_work_id_idx ON creative_work_translations USING btree (creative_work_id);


--
-- Name: creative_work_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX creative_work_locale_idx ON creative_work_translations USING btree (locale);


--
-- Name: cw_template_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cw_template_template_name_idx ON creative_works USING btree (template, template_name);


--
-- Name: delayed_jobs_delayed_reference_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_delayed_reference_id ON delayed_jobs USING btree (delayed_reference_id);


--
-- Name: delayed_jobs_delayed_reference_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_delayed_reference_type ON delayed_jobs USING btree (delayed_reference_type);


--
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_priority ON delayed_jobs USING btree (priority, run_at);


--
-- Name: delayed_jobs_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_queue ON delayed_jobs USING btree (queue);


--
-- Name: deleted_at_classification_alias_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_classification_alias_id_idx ON classification_trees USING btree (deleted_at, classification_alias_id);


--
-- Name: deleted_at_classification_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_classification_id_idx ON classification_groups USING btree (deleted_at, classification_id);


--
-- Name: deleted_at_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deleted_at_id_idx ON classification_aliases USING btree (deleted_at, id);


--
-- Name: ev_template_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ev_template_template_name_idx ON events USING btree (template, template_name);


--
-- Name: event_histories_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX event_histories_id_idx ON event_histories USING btree (id);


--
-- Name: event_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX event_history_id_idx ON event_history_translations USING btree (event_history_id);


--
-- Name: event_history_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX event_history_locale_idx ON event_history_translations USING btree (locale);


--
-- Name: event_id_foreign_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX event_id_foreign_key_idx ON event_histories USING btree (event_id);


--
-- Name: event_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX event_id_idx ON event_translations USING btree (event_id);


--
-- Name: event_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX event_locale_idx ON event_translations USING btree (locale);


--
-- Name: extid_extkey_del_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX extid_extkey_del_idx ON classifications USING btree (deleted_at, external_source_id, external_key);


--
-- Name: headline_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX headline_idx ON searches USING gin (headline gin_trgm_ops);


--
-- Name: index_asset_contents_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_asset_contents_on_asset_id ON asset_contents USING btree (asset_id);


--
-- Name: index_asset_contents_on_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_asset_contents_on_content_data_id ON asset_contents USING btree (content_data_id);


--
-- Name: index_classification_aliases_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_aliases_on_deleted_at ON classification_aliases USING btree (deleted_at);


--
-- Name: index_classification_aliases_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_aliases_on_id ON classification_aliases USING btree (id);


--
-- Name: index_classification_content_histories_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_content_histories_on_classification_id ON classification_content_histories USING btree (classification_id);


--
-- Name: index_classification_contents_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_contents_on_classification_id ON classification_contents USING btree (classification_id);


--
-- Name: index_classification_contents_on_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_contents_on_content_data_id ON classification_contents USING btree (content_data_id);


--
-- Name: index_classification_groups_on_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_classification_alias_id ON classification_groups USING btree (classification_alias_id);


--
-- Name: index_classification_groups_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_classification_id ON classification_groups USING btree (classification_id);


--
-- Name: index_classification_groups_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_deleted_at ON classification_groups USING btree (deleted_at);


--
-- Name: index_classification_groups_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_groups_on_external_source_id ON classification_groups USING btree (external_source_id);


--
-- Name: index_classification_tree_labels_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_tree_labels_on_deleted_at ON classification_tree_labels USING btree (deleted_at);


--
-- Name: index_classification_tree_labels_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classification_tree_labels_on_id ON classification_tree_labels USING btree (id);


--
-- Name: index_classification_trees_on_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_classification_alias_id ON classification_trees USING btree (classification_alias_id);


--
-- Name: index_classification_trees_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_deleted_at ON classification_trees USING btree (deleted_at);


--
-- Name: index_classification_trees_on_parent_classification_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classification_trees_on_parent_classification_alias_id ON classification_trees USING btree (parent_classification_alias_id);


--
-- Name: index_classifications_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_on_deleted_at ON classifications USING btree (deleted_at);


--
-- Name: index_classifications_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_on_external_source_id ON classifications USING btree (external_source_id);


--
-- Name: index_classifications_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classifications_on_id ON classifications USING btree (id);


--
-- Name: index_creative_works_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creative_works_on_content_type ON creative_works USING btree (((schema ->> 'content_type'::text)));


--
-- Name: index_creative_works_on_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creative_works_on_external_key ON creative_works USING btree (((metadata ->> 'external_key'::text)), external_source_id);


--
-- Name: index_creative_works_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creative_works_on_external_source_id ON creative_works USING btree (external_source_id);


--
-- Name: index_creative_works_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_creative_works_on_id ON creative_works USING btree (id);


--
-- Name: index_creative_works_on_is_part_of; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creative_works_on_is_part_of ON creative_works USING btree (is_part_of);


--
-- Name: index_creative_works_on_metadata_validation_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creative_works_on_metadata_validation_name ON creative_works USING btree (((metadata #>> '{validation,name}'::text[])));


--
-- Name: index_cw_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cw_on_external_source_id_and_external_key ON creative_works USING btree (external_source_id, external_key);


--
-- Name: index_data_links_on_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_asset_id ON data_links USING btree (asset_id);


--
-- Name: index_data_links_on_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_item_id ON data_links USING btree (item_id);


--
-- Name: index_data_links_on_item_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_links_on_item_type ON data_links USING btree (item_type);


--
-- Name: index_e_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_e_on_external_source_id_and_external_key ON events USING btree (external_source_id, external_key);


--
-- Name: index_events_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_content_type ON events USING btree (((schema ->> 'content_type'::text)));


--
-- Name: index_events_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_external_source_id ON events USING btree (external_source_id);


--
-- Name: index_events_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_events_on_id ON events USING btree (id);


--
-- Name: index_external_sources_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_sources_on_id ON external_sources USING btree (id);


--
-- Name: index_o_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_o_on_external_source_id_and_external_key ON organizations USING btree (external_source_id, external_key);


--
-- Name: index_organizations_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_content_type ON organizations USING btree (((schema ->> 'content_type'::text)));


--
-- Name: index_organizations_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_external_source_id ON organizations USING btree (external_source_id);


--
-- Name: index_organizations_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_id ON organizations USING btree (id);


--
-- Name: index_pers_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pers_on_external_source_id_and_external_key ON persons USING btree (external_source_id, external_key);


--
-- Name: index_persons_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persons_on_content_type ON persons USING btree (((schema ->> 'content_type'::text)));


--
-- Name: index_persons_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persons_on_external_source_id ON persons USING btree (external_source_id);


--
-- Name: index_persons_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_persons_on_id ON persons USING btree (id);


--
-- Name: index_places_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_content_type ON places USING btree (((schema ->> 'content_type'::text)));


--
-- Name: index_places_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_external_source_id ON places USING btree (external_source_id);


--
-- Name: index_places_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_places_on_external_source_id_and_external_key ON places USING btree (external_source_id, external_key);


--
-- Name: index_places_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_places_on_id ON places USING btree (id);


--
-- Name: index_places_on_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_location ON places USING gist (location);


--
-- Name: index_roles_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_name ON roles USING btree (name);


--
-- Name: index_roles_on_rank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_rank ON roles USING btree (rank);


--
-- Name: index_searches_on_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_content_data_id ON searches USING btree (content_data_id);


--
-- Name: index_searches_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_locale ON searches USING btree (locale);


--
-- Name: index_searches_on_locale_and_content_data_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_locale_and_content_data_id ON searches USING btree (locale, content_data_id);


--
-- Name: index_searches_on_words; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_words ON searches USING gin (words);


--
-- Name: index_stored_filters_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stored_filters_on_user_id ON stored_filters USING btree (user_id);


--
-- Name: index_subscriptions_on_subscribable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_subscribable_id ON subscriptions USING btree (subscribable_id);


--
-- Name: index_subscriptions_on_subscribable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_subscribable_type ON subscriptions USING btree (subscribable_type);


--
-- Name: index_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_user_id ON subscriptions USING btree (user_id);


--
-- Name: index_thing_histories_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_histories_on_id ON thing_histories USING btree (id);


--
-- Name: index_thing_histories_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_histories_on_thing_id ON thing_histories USING btree (thing_id);


--
-- Name: index_thing_history_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_id_locale ON thing_history_translations USING btree (thing_history_id, locale);


--
-- Name: index_thing_history_translations_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_history_translations_on_id ON thing_history_translations USING btree (id);


--
-- Name: index_thing_history_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_translations_on_locale ON thing_history_translations USING btree (locale);


--
-- Name: index_thing_history_translations_on_thing_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_history_translations_on_thing_history_id ON thing_history_translations USING btree (thing_history_id);


--
-- Name: index_thing_id_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_id_locale ON thing_translations USING btree (thing_id, locale);


--
-- Name: index_thing_translations_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_translations_on_id ON thing_translations USING btree (id);


--
-- Name: index_thing_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_translations_on_locale ON thing_translations USING btree (locale);


--
-- Name: index_thing_translations_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_translations_on_thing_id ON thing_translations USING btree (thing_id);


--
-- Name: index_things_on_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_content_type ON things USING btree (((schema ->> 'content_type'::text)));


--
-- Name: index_things_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_external_source_id ON things USING btree (external_source_id);


--
-- Name: index_things_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_things_on_external_source_id_and_external_key ON things USING btree (external_source_id, external_key);


--
-- Name: index_things_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_things_on_id ON things USING btree (id);


--
-- Name: index_things_template_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_template_template_name_idx ON things USING btree (template, template_name);


--
-- Name: index_use_cases_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_use_cases_on_external_source_id ON use_cases USING btree (external_source_id);


--
-- Name: index_use_cases_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_use_cases_on_id ON use_cases USING btree (id);


--
-- Name: index_use_cases_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_use_cases_on_user_id ON use_cases USING btree (user_id);


--
-- Name: index_user_group_users_on_user_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_group_users_on_user_group_id ON user_group_users USING btree (user_group_id);


--
-- Name: index_user_group_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_group_users_on_user_id ON user_group_users USING btree (user_id);


--
-- Name: index_user_groups_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_groups_on_id ON user_groups USING btree (id);


--
-- Name: index_user_groups_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_groups_on_name ON user_groups USING btree (name);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_id ON users USING btree (id);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON users USING btree (reset_password_token);


--
-- Name: index_watch_list_data_hashes_on_hashable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_hashable_id ON watch_list_data_hashes USING btree (hashable_id);


--
-- Name: index_watch_list_data_hashes_on_hashable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_hashable_type ON watch_list_data_hashes USING btree (hashable_type);


--
-- Name: index_watch_list_data_hashes_on_watch_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_data_hashes_on_watch_list_id ON watch_list_data_hashes USING btree (watch_list_id);


--
-- Name: index_watch_list_user_groups_on_user_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_user_groups_on_user_group_id ON watch_list_user_groups USING btree (user_group_id);


--
-- Name: index_watch_list_user_groups_on_watch_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_list_user_groups_on_watch_list_id ON watch_list_user_groups USING btree (watch_list_id);


--
-- Name: index_watch_lists_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_lists_on_id ON watch_lists USING btree (id);


--
-- Name: index_watch_lists_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watch_lists_on_user_id ON watch_lists USING btree (user_id);


--
-- Name: name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX name_idx ON classification_aliases USING gin (name gin_trgm_ops);


--
-- Name: or_template_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX or_template_template_name_idx ON organizations USING btree (template, template_name);


--
-- Name: organization_histories_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_histories_id_idx ON organization_histories USING btree (id);


--
-- Name: organization_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_history_id_idx ON organization_history_translations USING btree (organization_history_id);


--
-- Name: organization_history_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_history_locale_idx ON organization_history_translations USING btree (locale);


--
-- Name: organization_id_foreign_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_id_foreign_key_idx ON organization_histories USING btree (organization_id);


--
-- Name: organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_id_idx ON organization_translations USING btree (organization_id);


--
-- Name: organization_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_locale_idx ON organization_translations USING btree (locale);


--
-- Name: parent_child_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX parent_child_index ON classification_trees USING btree (parent_classification_alias_id, classification_alias_id);


--
-- Name: pe_template_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pe_template_template_name_idx ON persons USING btree (template, template_name);


--
-- Name: person_histories_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_histories_id_idx ON person_histories USING btree (id);


--
-- Name: person_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_history_id_idx ON person_history_translations USING btree (person_history_id);


--
-- Name: person_history_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_history_locale_idx ON person_history_translations USING btree (locale);


--
-- Name: person_id_foreign_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_id_foreign_key_idx ON person_histories USING btree (person_id);


--
-- Name: person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_id_idx ON person_translations USING btree (person_id);


--
-- Name: person_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_locale_idx ON person_translations USING btree (locale);


--
-- Name: pl_template_template_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pl_template_template_name_idx ON places USING btree (template, template_name);


--
-- Name: place_histories_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX place_histories_id_idx ON place_histories USING btree (id);


--
-- Name: place_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX place_history_id_idx ON place_history_translations USING btree (place_history_id);


--
-- Name: place_history_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX place_history_locale_idx ON place_history_translations USING btree (locale);


--
-- Name: place_id_foreign_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX place_id_foreign_key_idx ON place_histories USING btree (place_id);


--
-- Name: place_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX place_id_idx ON place_translations USING btree (place_id);


--
-- Name: place_locale_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX place_locale_idx ON place_translations USING btree (locale);


--
-- Name: validity_period_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX validity_period_idx ON searches USING gist (validity_period);


--
-- Name: words_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_idx ON searches USING gin (full_text gin_trgm_ops);


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
('20180920111943'),
('20180921083454');


