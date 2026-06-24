# frozen_string_literal: true

class AddIndexForClassificationAliasPathFullPathNames < ActiveRecord::Migration[7.1]
  def change
    add_index :classification_alias_paths, :full_path_names, name: 'classification_alias_paths_on_full_path_names_idx'
    add_index :concepts, :uri, name: 'index_concepts_on_uri'
  end
end
