# frozen_string_literal: true

class AddForeignKeyForClassificationContents < ActiveRecord::Migration[6.1]
  def change
    add_foreign_key :classification_contents, :things, column: :content_data_id, on_delete: :cascade, validate: false
  end
end
