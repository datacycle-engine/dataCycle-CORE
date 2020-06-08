# frozen_string_literal: true

class DeleteOldRelationTables < ActiveRecord::Migration[5.0]
  def up
    drop_table :creative_work_events
    drop_table :creative_work_event_histories
    drop_table :creative_work_persons
    drop_table :creative_work_person_histories
    drop_table :creative_work_places
    drop_table :creative_work_place_histories
    drop_table :event_persons
    drop_table :event_person_histories
    drop_table :event_places
    drop_table :event_place_histories
    drop_table :person_places
    drop_table :person_place_histories
  end

  def down
    sql_string = <<-EOS
      CREATE TABLE creative_work_event_histories (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          creative_work_history_id uuid,
          event_history_id uuid,
          history_valid tstzrange,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE creative_work_events (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          creative_work_id uuid,
          event_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL,
          external_source_id uuid
      );
      CREATE TABLE creative_work_person_histories (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          creative_work_history_id uuid,
          person_history_id uuid,
          history_valid tstzrange,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE creative_work_persons (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          creative_work_id uuid,
          person_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL,
          external_source_id uuid
      );
      CREATE TABLE creative_work_place_histories (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          creative_work_history_id uuid,
          place_history_id uuid,
          history_valid tstzrange,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE creative_work_places (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          creative_work_id uuid,
          place_id uuid,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE event_person_histories (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          event_history_id uuid,
          person_history_id uuid,
          history_valid tstzrange,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE event_persons (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          event_id uuid,
          person_id uuid,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE event_place_histories (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          event_history_id uuid,
          place_history_id uuid,
          history_valid tstzrange,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE event_places (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          event_id uuid,
          place_id uuid,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE person_place_histories (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          person_history_id uuid,
          place_history_id uuid,
          history_valid tstzrange,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
      CREATE TABLE person_places (
          id uuid DEFAULT uuid_generate_v4() NOT NULL,
          person_id uuid,
          place_id uuid,
          external_source_id uuid,
          seen_at timestamp without time zone,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
      );
    EOS
    ActiveRecord::Base.connection.execute(sql_string)
  end
end
