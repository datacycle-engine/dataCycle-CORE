SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

<<<<<<< HEAD
=======
SET search_path = public, pg_catalog;

>>>>>>> feature/search_tweak
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
    name character varying,
    metadata jsonb,
    duplicate_check jsonb
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
-- Name: classification_contents; Type: TABLE; Schema: public; Owner: -
--

<<<<<<< HEAD
CREATE TABLE public.classification_contents (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
=======
CREATE TABLE classification_contents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
>>>>>>> feature/search_tweak
    content_data_id uuid,
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

<<<<<<< HEAD
CREATE TABLE public.classification_groups (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
=======
CREATE TABLE classification_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
>>>>>>> feature/search_tweak
    classification_id uuid,
    classification_alias_id uuid,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- Name: classification_alias_statistics; Type: VIEW; Schema: public; Owner: -
--

<<<<<<< HEAD
CREATE VIEW public.classification_alias_statistics AS
=======
CREATE VIEW classification_alias_statistics AS
>>>>>>> feature/search_tweak
 WITH descendant_counts AS (
         SELECT classification_aliases_1.id,
            count(
                CASE
                    WHEN (exploded_classification_ancestors.ancestor_id IS NOT NULL) THEN 1
                    ELSE NULL::integer
                END) AS descendant_count
<<<<<<< HEAD
           FROM (public.classification_aliases classification_aliases_1
             JOIN ( SELECT unnest(classification_alias_paths.ancestor_ids) AS ancestor_id
                   FROM public.classification_alias_paths) exploded_classification_ancestors ON ((exploded_classification_ancestors.ancestor_id = classification_aliases_1.id)))
=======
           FROM (classification_aliases classification_aliases_1
             JOIN ( SELECT unnest(classification_alias_paths.ancestor_ids) AS ancestor_id
                   FROM classification_alias_paths) exploded_classification_ancestors ON ((exploded_classification_ancestors.ancestor_id = classification_aliases_1.id)))
>>>>>>> feature/search_tweak
          GROUP BY classification_aliases_1.id
        ), linked_content_counts AS (
         SELECT classification_aliases_1.id,
            count(
                CASE
                    WHEN (classification_aliases_1.id IS NOT NULL) THEN 1
                    ELSE NULL::integer
                END) AS linked_content_count
<<<<<<< HEAD
           FROM (((public.classification_aliases classification_aliases_1
             JOIN public.classification_alias_paths ON ((classification_aliases_1.id = classification_alias_paths.id)))
             JOIN public.classification_groups ON ((classification_aliases_1.id = classification_groups.classification_alias_id)))
             JOIN public.classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
=======
           FROM (((classification_aliases classification_aliases_1
             JOIN classification_alias_paths ON ((classification_aliases_1.id = classification_alias_paths.id)))
             JOIN classification_groups ON ((classification_aliases_1.id = classification_groups.classification_alias_id)))
             JOIN classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
>>>>>>> feature/search_tweak
          GROUP BY classification_aliases_1.id
        ), descendants_linked_content_counts AS (
         SELECT exploded_classification_ancestors.ancestor_id AS id,
            count(*) AS linked_content_count
           FROM ((( SELECT unnest(classification_alias_paths.ancestor_ids) AS ancestor_id,
                    classification_alias_paths.id AS classification_alias_id
<<<<<<< HEAD
                   FROM public.classification_alias_paths) exploded_classification_ancestors
             JOIN public.classification_groups ON ((exploded_classification_ancestors.classification_alias_id = classification_groups.classification_alias_id)))
             JOIN public.classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
=======
                   FROM classification_alias_paths) exploded_classification_ancestors
             JOIN classification_groups ON ((exploded_classification_ancestors.classification_alias_id = classification_groups.classification_alias_id)))
             JOIN classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
>>>>>>> feature/search_tweak
          GROUP BY exploded_classification_ancestors.ancestor_id
        )
 SELECT classification_aliases.id,
    COALESCE(descendant_counts.descendant_count, (0)::bigint) AS descendant_count,
    (COALESCE(linked_content_counts.linked_content_count, (0)::bigint) + COALESCE(descendants_linked_content_counts.linked_content_count, (0)::bigint)) AS linked_content_count
<<<<<<< HEAD
   FROM (((public.classification_aliases
=======
   FROM (((classification_aliases
>>>>>>> feature/search_tweak
     LEFT JOIN descendant_counts ON ((descendant_counts.id = classification_aliases.id)))
     LEFT JOIN linked_content_counts ON ((linked_content_counts.id = classification_aliases.id)))
     LEFT JOIN descendants_linked_content_counts ON ((descendants_linked_content_counts.id = classification_aliases.id)));


--
-- Name: classification_content_histories; Type: TABLE; Schema: public; Owner: -
--

<<<<<<< HEAD
CREATE TABLE public.classification_content_histories (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
=======
CREATE TABLE classification_content_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
>>>>>>> feature/search_tweak
    content_data_history_id uuid,
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
-- Name: classification_tree_label_statistics; Type: VIEW; Schema: public; Owner: -
--

<<<<<<< HEAD
CREATE VIEW public.classification_tree_label_statistics AS
=======
CREATE VIEW classification_tree_label_statistics AS
>>>>>>> feature/search_tweak
 WITH descendant_counts AS (
         SELECT classification_tree_labels_1.id,
            count(
                CASE
                    WHEN (classification_aliases.id IS NOT NULL) THEN 1
                    ELSE NULL::integer
                END) AS descendant_count
<<<<<<< HEAD
           FROM ((public.classification_tree_labels classification_tree_labels_1
             JOIN public.classification_trees ON ((classification_tree_labels_1.id = classification_trees.classification_tree_label_id)))
             JOIN public.classification_aliases ON ((classification_trees.classification_alias_id = classification_aliases.id)))
=======
           FROM ((classification_tree_labels classification_tree_labels_1
             JOIN classification_trees ON ((classification_tree_labels_1.id = classification_trees.classification_tree_label_id)))
             JOIN classification_aliases ON ((classification_trees.classification_alias_id = classification_aliases.id)))
>>>>>>> feature/search_tweak
          GROUP BY classification_tree_labels_1.id
        ), linked_content_counts AS (
         SELECT classification_tree_labels_1.id,
            count(
                CASE
                    WHEN (classification_aliases.id IS NOT NULL) THEN 1
                    ELSE NULL::integer
                END) AS linked_content_count
<<<<<<< HEAD
           FROM ((((public.classification_tree_labels classification_tree_labels_1
             JOIN public.classification_trees ON ((classification_tree_labels_1.id = classification_trees.classification_tree_label_id)))
             JOIN public.classification_aliases ON ((classification_trees.classification_alias_id = classification_aliases.id)))
             JOIN public.classification_groups ON ((classification_aliases.id = classification_groups.classification_alias_id)))
             JOIN public.classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
=======
           FROM ((((classification_tree_labels classification_tree_labels_1
             JOIN classification_trees ON ((classification_tree_labels_1.id = classification_trees.classification_tree_label_id)))
             JOIN classification_aliases ON ((classification_trees.classification_alias_id = classification_aliases.id)))
             JOIN classification_groups ON ((classification_aliases.id = classification_groups.classification_alias_id)))
             JOIN classification_contents ON ((classification_groups.classification_id = classification_contents.classification_id)))
>>>>>>> feature/search_tweak
          GROUP BY classification_tree_labels_1.id
        )
 SELECT classification_tree_labels.id,
    COALESCE(descendant_counts.descendant_count, (0)::bigint) AS descendant_count,
    COALESCE(linked_content_counts.linked_content_count, (0)::bigint) AS linked_content_count
<<<<<<< HEAD
   FROM ((public.classification_tree_labels
=======
   FROM ((classification_tree_labels
>>>>>>> feature/search_tweak
     LEFT JOIN descendant_counts ON ((descendant_counts.id = classification_tree_labels.id)))
     LEFT JOIN linked_content_counts ON ((linked_content_counts.id = classification_tree_labels.id)));


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
    relation_a character varying,
    content_b_history_id uuid,
    content_b_history_type character varying,
    history_valid tstzrange,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    order_a integer
);


--
-- Name: content_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_contents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_a_id uuid,
    relation_a character varying,
    content_b_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    order_a integer
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
    deleted_at timestamp without time zone,
    given_name character varying,
    family_name character varying,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    longitude double precision,
    latitude double precision,
    elevation double precision,
    location geometry(Point,4326),
    line geography(LineStringZ,4326),
    address_locality character varying,
    street_address character varying,
    postal_code character varying,
    address_country character varying,
    fax_number character varying,
    telephone character varying,
    email character varying,
    is_part_of uuid,
    validity_range tstzrange,
    boost numeric
);


--
-- Name: content_meta_items; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW content_meta_items AS
 SELECT things.id,
    'DataCycleCore::Thing' AS content_type,
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

<<<<<<< HEAD
CREATE SEQUENCE public.delayed_jobs_id_seq
=======
CREATE SEQUENCE delayed_jobs_id_seq
>>>>>>> feature/search_tweak
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
-- Name: external_systems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE external_systems (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    config jsonb,
    credentials jsonb,
    default_options jsonb,
    data jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: primary_classification_groups; Type: VIEW; Schema: public; Owner: -
--

<<<<<<< HEAD
CREATE VIEW public.primary_classification_groups AS
=======
CREATE VIEW primary_classification_groups AS
>>>>>>> feature/search_tweak
 SELECT DISTINCT ON (classification_groups.classification_id) classification_groups.id,
    classification_groups.classification_id,
    classification_groups.classification_alias_id,
    classification_groups.external_source_id,
    classification_groups.seen_at,
    classification_groups.created_at,
    classification_groups.updated_at,
    classification_groups.deleted_at
<<<<<<< HEAD
   FROM public.classification_groups
=======
   FROM classification_groups
>>>>>>> feature/search_tweak
  ORDER BY classification_groups.classification_id, classification_groups.created_at;


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
-- Name: thing_external_systems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE thing_external_systems (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thing_id uuid,
    external_system_id uuid,
    data jsonb,
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
    deleted_at timestamp without time zone,
    given_name character varying,
    family_name character varying,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    longitude double precision,
    latitude double precision,
    elevation double precision,
    location geometry(Point,4326),
    line geography(LineStringZ,4326),
    address_locality character varying,
    street_address character varying,
    postal_code character varying,
    address_country character varying,
    fax_number character varying,
    telephone character varying,
    email character varying,
    is_part_of uuid,
    validity_range tstzrange,
    boost numeric
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
    name character varying,
    user_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY delayed_jobs ALTER COLUMN id SET DEFAULT nextval('delayed_jobs_id_seq'::regclass);


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
-- Name: external_sources external_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY external_sources
    ADD CONSTRAINT external_sources_pkey PRIMARY KEY (id);


--
-- Name: external_systems external_systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY external_systems
    ADD CONSTRAINT external_systems_pkey PRIMARY KEY (id);


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
-- Name: thing_external_systems thing_external_systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY thing_external_systems
    ADD CONSTRAINT thing_external_systems_pkey PRIMARY KEY (id);


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
-- Name: by_content_relation_a; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX by_content_relation_a ON content_contents USING btree (content_a_id, relation_a, content_b_id);


--
-- Name: by_ctl_esi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_ctl_esi ON classification_tree_labels USING btree (external_source_id);


--
-- Name: child_parent_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX child_parent_index ON classification_trees USING btree (classification_alias_id, parent_classification_alias_id);


--
-- Name: classification_content_data_history_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_content_data_history_id_idx ON classification_content_histories USING btree (content_data_history_id);


--
-- Name: classification_string_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classification_string_idx ON searches USING gin (classification_string gin_trgm_ops);


--
-- Name: classified_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classified_name_idx ON stored_filters USING btree (api, system, name);


--
-- Name: content_b_history_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_b_history_idx ON content_content_histories USING btree (content_b_history_type, content_b_history_id);


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
-- Name: index_external_sources_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_sources_on_id ON external_sources USING btree (id);


--
-- Name: index_external_systems_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_systems_on_id ON external_systems USING btree (id);


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
-- Name: index_searches_on_content_data_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_searches_on_content_data_id_and_locale ON searches USING btree (content_data_id, locale);


--
-- Name: index_searches_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searches_on_locale ON searches USING btree (locale);


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
-- Name: index_thing_external_systems_on_thing_id_and_external_system_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_external_systems_on_thing_id_and_external_system_id ON thing_external_systems USING btree (thing_id, external_system_id);


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
-- Name: index_things_on_boost; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_boost ON things USING btree (boost DESC NULLS LAST);


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
-- Name: index_validity_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_validity_range ON things USING gist (validity_range);


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
-- Name: parent_child_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX parent_child_index ON classification_trees USING btree (parent_classification_alias_id, classification_alias_id);


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
<<<<<<< HEAD
('20181231081526');
=======
('20181231081526'),
('20190107074405'),
('20190108154224');
>>>>>>> feature/search_tweak


