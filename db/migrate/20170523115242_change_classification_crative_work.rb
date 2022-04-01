# frozen_string_literal: true

class ChangeClassificationCrativeWork < ActiveRecord::Migration[5.0]
  def change
    rename_column :classification_creative_works, :classification_alias_id, :classification_id
  end
end
