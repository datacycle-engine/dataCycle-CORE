class AddHistoryCreativeWork < ActiveRecord::Migration[5.0]
  def change

    create_table :creative_work_histories, id: :uuid do |t|
      t.uuid :creative_work_id
      t.integer :version
      t.integer :position, default: 0, null: 0
      t.uuid :isPartOf
      t.jsonb :metadata
      t.uuid :external_source_id
      t.boolean :template
      t.datetime :seen_at
      t.timestamps
      t.tstzrange :valid_period
    end

    create_table :creative_work_history_translations do |t|
      t.uuid :creative_work_history_id
      t.string :locale
      t.jsonb :content
      t.jsonb :properties
      t.text :headline
      t.text :description
      t.jsonb :release
      t.uuid :release_id
      t.text :release_comment
      t.timestamps
    end

  end
end
