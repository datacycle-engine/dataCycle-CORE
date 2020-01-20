# frozen_string_literal: true

class AddClassificationMappingToSearch < ActiveRecord::Migration[5.2]
  def change
    add_column :searches, :classification_mapping, :jsonb
    add_index :searches, :classification_mapping, using: :gin
  end
end
