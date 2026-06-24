# frozen_string_literal: true

class AddIndexForDuplicateCandidateModules < ActiveRecord::Migration[8.0]
  def change
    add_index :thing_templates, "(schema -> 'features' -> 'duplicate_candidate' -> 'module')", name: 'index_tt_on_duplicate_candidate_modules', if_not_exists: true
  end
end
