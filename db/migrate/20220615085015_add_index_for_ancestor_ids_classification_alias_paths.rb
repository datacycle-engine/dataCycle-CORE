# frozen_string_literal: true

class AddIndexForAncestorIdsClassificationAliasPaths < ActiveRecord::Migration[6.1]
  def change
    add_index :classification_alias_paths, :ancestor_ids, name: 'index_classification_alias_paths_on_ancestor_ids', using: :gin, if_not_exists: true
  end
end
