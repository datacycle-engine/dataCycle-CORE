# frozen_string_literal: true

class AddPrimaryIndexSearches < ActiveRecord::Migration[5.0]
  def change
    add_index :searches, [:content_data_id, :content_data_type, :locale], unique: true, name: 'by_content_data_locale'
  end
end
