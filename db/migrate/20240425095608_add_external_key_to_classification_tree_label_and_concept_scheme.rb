# frozen_string_literal: true

class AddExternalKeyToClassificationTreeLabelAndConceptScheme < ActiveRecord::Migration[6.1]
  def change
    add_column(:classification_tree_labels, :external_key, :string)
    add_column(:concept_schemes, :external_key, :string)
    add_column(:concept_scheme_histories, :external_key, :string)
    add_index(:concept_schemes, [:external_system_id, :external_key], unique: true)
    add_index(:classification_tree_labels, [:external_source_id, :external_key], unique: true, where: 'deleted_at IS NULL', name: 'index_ctl_on_external_source_id_and_external_key')
  end
end
