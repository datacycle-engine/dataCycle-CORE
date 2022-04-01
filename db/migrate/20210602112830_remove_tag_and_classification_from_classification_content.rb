# frozen_string_literal: true

class RemoveTagAndClassificationFromClassificationContent < ActiveRecord::Migration[5.2]
  def change
    remove_column :classification_contents, :classification, :boolean
    remove_column :classification_contents, :tag, :boolean
    remove_column :classification_contents, :external_source_id, :uuid
    remove_column :classification_content_histories, :classification, :boolean
    remove_column :classification_content_histories, :tag, :boolean
    remove_column :classification_content_histories, :external_source_id, :uuid
  end
end
