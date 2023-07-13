# frozen_string_literal: true

class MigrateClassificationTreeLabelVisibilities < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE
        classification_tree_labels
      SET
        visibility = ARRAY_REMOVE(visibility, 'show_more')
      WHERE
        classification_tree_labels.visibility @> ARRAY['show', 'show_more']::VARCHAR[]
    SQL
  end

  def down
  end
end
