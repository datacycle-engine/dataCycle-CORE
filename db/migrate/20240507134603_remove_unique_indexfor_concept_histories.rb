# frozen_string_literal: true

class RemoveUniqueIndexforConceptHistories < ActiveRecord::Migration[6.1]
  def change
    remove_index :concept_histories, [:external_system_id, :external_key], unique: true, where: 'external_system_id IS NOT NULL AND external_key IS NOT NULL'
  end
end
