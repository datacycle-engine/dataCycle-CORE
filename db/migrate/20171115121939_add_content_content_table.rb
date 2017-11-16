class AddContentContentTable < ActiveRecord::Migration[5.0]
  def change

    create_table :content_contents, id: :uuid do |t|
      t.uuid :content_a_id
      t.string :content_a_type
      t.string :relation_a
      t.uuid :content_b_id
      t.string :content_b_type
      t.string :relation_b
      t.uuid :external_source_id
      t.timestamps
    end

    add_index :content_contents, [:content_a_type, :content_a_id], name: "content_a_idx"
    add_index :content_contents, [:content_b_type, :content_b_id], name: "content_b_idx"

    create_table :content_content_histories, id: :uuid do |t|
      t.uuid :content_a_history_id
      t.string :content_a_history_type
      t.string :relation_a
      t.uuid :content_b_history_id
      t.string :content_b_history_type
      t.string :relation_b
      t.uuid :external_source_id
      t.tstzrange :history_valid
      t.timestamps
    end

    add_index :content_content_histories, [:content_a_history_type, :content_a_history_id], name: "content_a_history_idx"
    add_index :content_content_histories, [:content_b_history_type, :content_b_history_id], name: "content_b_history_idx"

  end
end
