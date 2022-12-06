# frozen_string_literal: true

class AddNewClassificationTreeVisibility < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL
      UPDATE
        classification_tree_labels
      SET
        visibility = visibility || 'classification_administration'::VARCHAR
      WHERE
        internal = FALSE
        AND 'classification_administration'::VARCHAR != ALL (visibility);
    SQL
  end

  def down
  end
end
