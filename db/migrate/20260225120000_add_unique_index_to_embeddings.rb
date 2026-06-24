# frozen_string_literal: true

class AddUniqueIndexToEmbeddings < ActiveRecord::Migration[7.1]
  def change
    add_index :embeddings,
              [:thing_id, :external_system_id],
              unique: true,
              name: 'index_embeddings_on_thing_and_external_system'
  end
end
