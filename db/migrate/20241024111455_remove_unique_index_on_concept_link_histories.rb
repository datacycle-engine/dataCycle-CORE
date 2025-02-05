# frozen_string_literal: true

class RemoveUniqueIndexOnConceptLinkHistories < ActiveRecord::Migration[6.1]
  def change
    remove_index :concept_link_histories, [:parent_id, :child_id], unique: true, if_exists: true
    remove_index :concept_link_histories, :child_id, unique: true, where: "link_type = 'broader'", if_exists: true
  end
end
