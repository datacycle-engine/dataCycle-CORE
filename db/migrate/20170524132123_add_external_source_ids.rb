# frozen_string_literal: true

class AddExternalSourceIds < ActiveRecord::Migration[5.0]
  def change
    add_column :classification_aliases, :external_source_id, :uuid
    add_column :classification_creative_works, :external_source_id, :uuid
  end
end
