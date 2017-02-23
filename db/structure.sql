--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.1
-- Dumped by pg_dump version 9.6.1

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
-- Name: classifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classifications (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
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
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: classifications_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classifications_aliases (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    name character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: classifications_creative_works; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classifications_creative_works (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    creative_work_id uuid,
    classifications_alias_id uuid,
    tag boolean DEFAULT false NOT NULL,
    classification boolean DEFAULT false NOT NULL,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: classifications_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classifications_groups (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    classification_id uuid,
    classifications_alias_id uuid,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: classifications_places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classifications_places (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    place_id uuid,
    classification_id uuid,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: classifications_trees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classifications_trees (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    external_source_id uuid,
    parent_classifications_alias_id uuid,
    classifications_alias_id uuid,
    relationship_label character varying,
    classifications_trees_label_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: classifications_trees_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE classifications_trees_labels (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    name character varying,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: creative_work_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE creative_work_translations (
    id integer NOT NULL,
    creative_work_id uuid NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    content jsonb,
    properties jsonb
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
-- Name: creative_works; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE creative_works (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    headline character varying,
    description text,
    "position" integer DEFAULT 0,
    "isPartOf" uuid,
    metadata jsonb,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_source_id uuid
);


--
-- Name: creative_works_places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE creative_works_places (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    creative_work_id uuid,
    place_id uuid,
    external_source_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


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
-- Name: external_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE external_sources (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    external_name character varying,
    credentials jsonb,
    config jsonb,
    last_download timestamp without time zone,
    last_import timestamp without time zone
);


--
-- Name: overlays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE overlays (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    overlay_data jsonb,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: overlays_places_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE overlays_places_tags (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    overlay_id uuid,
    place_id uuid,
    tag_id uuid,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: place_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE place_translations (
    id integer NOT NULL,
    place_id uuid NOT NULL,
    locale character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying,
    description character varying,
    "addressLocality" character varying,
    "streetAddress" character varying,
    "postalCode" character varying,
    "addressCountry" character varying,
    "faxNumber" character varying,
    telephone character varying,
    email character varying,
    url character varying,
    "hoursAvailable" character varying
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
-- Name: places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE places (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    external_source_id uuid,
    external_key character varying,
    longitude double precision,
    latitude double precision,
    elevation double precision,
    location geometry(Point,4326),
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    photo uuid
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE tags (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    name character varying,
    seen_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: use_cases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE use_cases (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    user_id uuid,
    external_source_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE users (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    admin boolean DEFAULT false NOT NULL,
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
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: creative_work_translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY creative_work_translations ALTER COLUMN id SET DEFAULT nextval('creative_work_translations_id_seq'::regclass);


--
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY delayed_jobs ALTER COLUMN id SET DEFAULT nextval('delayed_jobs_id_seq'::regclass);


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
-- Name: classifications_aliases classifications_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classifications_aliases
    ADD CONSTRAINT classifications_aliases_pkey PRIMARY KEY (id);


--
-- Name: classifications_creative_works classifications_creative_works_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classifications_creative_works
    ADD CONSTRAINT classifications_creative_works_pkey PRIMARY KEY (id);


--
-- Name: classifications_groups classifications_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classifications_groups
    ADD CONSTRAINT classifications_groups_pkey PRIMARY KEY (id);


--
-- Name: classifications classifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classifications
    ADD CONSTRAINT classifications_pkey PRIMARY KEY (id);


--
-- Name: classifications_places classifications_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classifications_places
    ADD CONSTRAINT classifications_places_pkey PRIMARY KEY (id);


--
-- Name: classifications_trees_labels classifications_trees_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classifications_trees_labels
    ADD CONSTRAINT classifications_trees_labels_pkey PRIMARY KEY (id);


--
-- Name: classifications_trees classifications_trees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY classifications_trees
    ADD CONSTRAINT classifications_trees_pkey PRIMARY KEY (id);


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
-- Name: creative_works_places creative_works_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY creative_works_places
    ADD CONSTRAINT creative_works_places_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: external_sources external_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY external_sources
    ADD CONSTRAINT external_sources_pkey PRIMARY KEY (id);


--
-- Name: overlays overlays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY overlays
    ADD CONSTRAINT overlays_pkey PRIMARY KEY (id);


--
-- Name: overlays_places_tags overlays_places_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY overlays_places_tags
    ADD CONSTRAINT overlays_places_tags_pkey PRIMARY KEY (id);


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
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: use_cases use_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY use_cases
    ADD CONSTRAINT use_cases_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: child_parent_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX child_parent_index ON classifications_trees USING btree (classifications_alias_id, parent_classifications_alias_id);


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
-- Name: index_classifications_places_on_classification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_places_on_classification_id ON classifications_places USING btree (classification_id);


--
-- Name: index_classifications_places_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_places_on_place_id ON classifications_places USING btree (place_id);


--
-- Name: index_classifications_trees_on_classifications_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_trees_on_classifications_alias_id ON classifications_trees USING btree (classifications_alias_id);


--
-- Name: index_classifications_trees_on_parent_classifications_alias_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classifications_trees_on_parent_classifications_alias_id ON classifications_trees USING btree (parent_classifications_alias_id);


--
-- Name: index_creative_work_translations_on_creative_work_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creative_work_translations_on_creative_work_id ON creative_work_translations USING btree (creative_work_id);


--
-- Name: index_creative_work_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creative_work_translations_on_locale ON creative_work_translations USING btree (locale);


--
-- Name: index_creative_works_on_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creative_works_on_external_key ON creative_works USING btree (((metadata ->> 'external_key'::text)), external_source_id);


--
-- Name: index_external_sources_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_sources_on_id ON external_sources USING btree (id);


--
-- Name: index_place_translations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_place_translations_on_locale ON place_translations USING btree (locale);


--
-- Name: index_place_translations_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_place_translations_on_place_id ON place_translations USING btree (place_id);


--
-- Name: index_places_on_external_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_external_source_id ON places USING btree (external_source_id);


--
-- Name: index_places_on_external_source_id_and_external_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_places_on_external_source_id_and_external_key ON places USING btree (external_source_id, external_key);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON users USING btree (reset_password_token);


--
-- Name: parent_child_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX parent_child_index ON classifications_trees USING btree (parent_classifications_alias_id, classifications_alias_id);


--
-- Name: place_classification_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX place_classification_index ON classifications_places USING btree (external_source_id, place_id, classification_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO public, postgis;

INSERT INTO schema_migrations (version) VALUES ('20170116165448'), ('20170118091809'), ('20170131141857'), ('20170131145138'), ('20170202142906'), ('20170209101956'), ('20170209115919'), ('20170213144933');


