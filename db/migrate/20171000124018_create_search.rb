# frozen_string_literal: true

class CreateSearch < ActiveRecord::Migration[5.0]
  def up
    create_table :searches, id: :uuid do |t|
      t.uuid :content_data_id
      t.string :content_data_type
      t.string :locale
      t.tsvector :words
      t.text :full_text
      t.timestamps
    end

    create_table :classification_contents, id: :uuid do |t|
      t.uuid :content_data_id
      t.string :content_data_type
      t.uuid :classification_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
      t.uuid :external_source_id
    end

    create_table :classification_content_histories, id: :uuid do |t|
      t.uuid :content_data_history_id
      t.string :content_data_history_type
      t.uuid :classification_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
      t.uuid :external_source_id
    end

    # data_migration:
    @connection = ActiveRecord::Base.connection
    data_hash = [
      { name: 'creative_work', content_type: 'DataCycleCore::CreativeWork' },
      { name: 'event', content_type: 'DataCycleCore::Event' },
      { name: 'place', content_type: 'DataCycleCore::Place' },
      { name: 'person', content_type: 'DataCycleCore::Person' }
    ]

    data_hash.each do |item|
      sql_query = <<-EOS
        INSERT INTO classification_contents
        SELECT id,
          #{item[:name]}_id AS content_data_id,
          '#{item[:content_type]}' AS content_data_type,
          classification_id,
          tag, classification,
          seen_at, created_at, updated_at,
          external_source_id
        FROM classification_#{item[:name]}s;
      EOS
      @connection.exec_query(sql_query)
      drop_table :"classification_#{item[:name]}s"

      sql_query = <<-EOS
        INSERT INTO classification_content_histories
        SELECT id,
          #{item[:name]}_history_id AS content_data_history_id,
          '#{item[:content_type]}::History' AS content_data_history_type,
          classification_id,
          tag, classification,
          seen_at, created_at, updated_at,
          external_source_id
        FROM classification_#{item[:name]}_histories;
      EOS
      @connection.exec_query(sql_query)
      drop_table :"classification_#{item[:name]}_histories"
    end
  end

  def down
    # data split:
    @connection = ActiveRecord::Base.connection
    data_hash = [
      { name: 'creative_work', content_type: 'DataCycleCore::CreativeWork' },
      { name: 'event', content_type: 'DataCycleCore::Event' },
      { name: 'place', content_type: 'DataCycleCore::Place' },
      { name: 'person', content_type: 'DataCycleCore::Person' }
    ]

    data_hash.each do |item|
      create_table :"classification_#{item[:name]}s", id: :uuid do |t|
        t.uuid :"#{item[:name]}_id"
        t.uuid :classification_id
        t.boolean :tag, default: false, null: false
        t.boolean :classification, default: false, null: false
        t.datetime :seen_at
        t.timestamps
        t.uuid :external_source_id
      end

      create_table "classification_#{item[:name]}_histories", id: :uuid do |t|
        t.uuid "#{item[:name]}_history_id"
        t.uuid :classification_id
        t.boolean :tag, default: false, null: false
        t.boolean :classification, default: false, null: false
        t.datetime :seen_at
        t.timestamps
        t.uuid :external_source_id
      end

      sql_query = <<-EOS
        INSERT INTO classification_#{item[:name]}s
        SELECT id,
          content_id AS #{item[:name]}_id,
          classification_id,
          tag, classification,
          seen_at, created_at, updated_at,
          external_source_id
        FROM classification_contents
        WHERE content_type = '#{item[:content_type]}';
      EOS
      @connection.exec_query(sql_query)

      sql_query = <<-EOS
        INSERT INTO classification_#{item[:name]}_histories
        SELECT id,
          content_history_id AS #{item[:name]}_history_id,
          classification_id,
          tag, classification,
          seen_at, created_at, updated_at,
          external_source_id
        FROM classification_content_histories
        WHERE content_history_type = '#{item[:content_type]}::History';
      EOS
      @connection.exec_query(sql_query)
    end

    drop_table :classification_content_histories
    drop_table :classification_contents
    drop_table :searches
  end
end
