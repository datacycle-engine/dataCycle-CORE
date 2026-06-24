# frozen_string_literal: true

class RemoveCompactFromDefaulClassificationVisibilities < ActiveRecord::Migration[8.0]
  # uncomment the following line to disable transactions
  disable_ddl_transaction!

  def up
    execute <<~SQL
      UPDATE classification_tree_labels
      SET visibility = array_remove(visibility, 'compact')
      WHERE visibility @> ARRAY['compact']::varchar[];
    SQL
  end

  def down
  end
end
