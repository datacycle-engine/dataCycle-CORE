# frozen_string_literal: true

class AddIndexForOrderedConcepts < ActiveRecord::Migration[6.1]
  def change
    add_index(:concepts, [:order_a, :id, :concept_scheme_id], if_not_exists: true, name: 'index_concepts_on_full_order_concept_scheme_id')
  end
end
