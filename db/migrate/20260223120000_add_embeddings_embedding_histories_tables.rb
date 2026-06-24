# frozen_string_literal: true

class AddEmbeddingsEmbeddingHistoriesTables < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'vector' unless extension_enabled?('vector')

    create_table :embeddings, id: :uuid do |t|
      t.references :thing, foreign_key: { on_delete: :cascade }, type: :uuid, null: false
      t.references :external_system, foreign_key: { on_delete: :cascade }, type: :uuid, null: false
      t.column :embedding, 'vector'
      t.integer :dimensions
      t.jsonb :data
      t.timestamps
    end

    create_table :embedding_histories, id: :uuid do |t|
      t.references :thing_history, foreign_key: { on_delete: :cascade }, type: :uuid, null: false
      t.references :external_system, foreign_key: { on_delete: :cascade }, type: :uuid, null: false
      t.column :embedding, 'vector'
      t.integer :dimensions
      t.jsonb :data
      t.timestamps
    end
  end
end
