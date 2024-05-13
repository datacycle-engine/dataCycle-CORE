# frozen_string_literal: true

class GenerateExternalKeyForClassificationTreeLabels < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE classification_tree_labels
      SET external_key = classification_tree_labels.name
      WHERE classification_tree_labels.id IN (
          SELECT ctl.id
          FROM classification_tree_labels ctl
            INNER JOIN external_systems es ON es.id = ctl.external_source_id
          WHERE ctl.external_source_id IS NOT NULL
            AND ctl.external_key IS NULL
        );
    SQL
  end

  def down
  end
end
