# frozen_string_literal: true

class AddIndexesSearch < ActiveRecord::Migration[5.1]
  def change
    add_index :searches, :locale unless index_exists?(:searches, :locale)
    add_index :searches, :content_data_id unless index_exists?(:searches, :content_data_id)
    add_index :searches, [:locale, :content_data_id] unless index_exists?(:searches, [:locale, :content_data_id])
  end
end
