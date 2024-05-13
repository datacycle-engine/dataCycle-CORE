# frozen_string_literal: true

class AddIndexToConceptsAndConceptSchemes < ActiveRecord::Migration[6.1]
  def change
    remove_index(:concepts, :internal_name, using: 'gin', opclass: :gin_trgm_ops, if_exists: true)
    add_index(:concepts, :internal_name, if_not_exists: true, name: 'index_concepts_on_internal_name_btree')
    add_index(:concepts, :internal_name, using: 'gin', opclass: :gin_trgm_ops, if_not_exists: true, name: 'index_concepts_on_internal_name_gin')
  end
end
