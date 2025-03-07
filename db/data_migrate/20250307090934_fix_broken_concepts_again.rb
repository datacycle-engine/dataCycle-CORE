# frozen_string_literal: true

class FixBrokenConceptsAgain < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE concepts
      SET concept_scheme_id = to_update.classification_tree_label_id
      FROM (
          SELECT concepts.id,
            ct.classification_tree_label_id
          FROM concepts
            JOIN classification_trees ct ON ct.classification_alias_id = concepts.id
          WHERE concept_scheme_id IS NULL
        ) to_update
      WHERE concepts.id = to_update.id;

      UPDATE concepts
      SET classification_id = to_update.classification_id
      FROM (
          SELECT concepts.id,
            pcg.classification_id
          FROM concepts
            JOIN primary_classification_groups pcg ON pcg.classification_alias_id = concepts.id
          WHERE concepts.classification_id IS NULL
        ) to_update
      WHERE concepts.id = to_update.id;
    SQL
  end

  def down
  end
end
