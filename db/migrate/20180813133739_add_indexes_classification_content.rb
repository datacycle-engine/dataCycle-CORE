# frozen_string_literal: true

class AddIndexesClassificationContent < ActiveRecord::Migration[5.1]
  def change
    add_index :classification_contents, :content_data_id unless index_exists?(:classification_contents, :content_data_id)
    add_index :classification_content_histories, :content_data_history_id, name: 'classification_content_data_history_id_idx' unless index_exists?(:classification_content_histories, :content_data_history_id, name: 'classification_content_data_history_id_idx')
  end
end
