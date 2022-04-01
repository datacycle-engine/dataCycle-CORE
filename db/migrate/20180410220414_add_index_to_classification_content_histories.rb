# frozen_string_literal: true

class AddIndexToClassificationContentHistories < ActiveRecord::Migration[5.0]
  def up
    add_index :classification_content_histories, :classification_id unless index_exists?(:classification_content_histories, :classification_id)
    add_index :classification_content_histories, [:content_data_history_type, :content_data_history_id], name: 'classification_content_data_history_idx' unless index_exists?(:classification_content_histories, [:content_data_history_type, :content_data_history_id], name: 'classification_content_data_history_idx')
    remove_index :classification_contents, :content_data_id
    add_index :classification_contents, [:content_data_type, :content_data_id], name: 'classification_content_data_idx' unless index_exists?(:classification_contents, [:content_data_type, :content_data_id], name: 'classification_content_data_idx')
  end

  def down
    remove_index :classification_contents, [:content_data_type, :content_data_id], name: 'classification_content_data_idx'
    add_index :classification_contents, :content_data_id unless index_exists?(:classification_contents, :content_data_id)
    remove_index :classification_content_histories, [:content_data_history_type, :content_data_history_id], name: 'classification_content_data_history_idx'
    remove_index :classification_content_histories, :classification_id
  end
end
