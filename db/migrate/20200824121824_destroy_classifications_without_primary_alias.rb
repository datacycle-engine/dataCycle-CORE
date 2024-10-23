# frozen_string_literal: true

class DestroyClassificationsWithoutPrimaryAlias < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      DELETE FROM classifications
      WHERE NOT EXISTS (
        SELECT
        FROM primary_classification_groups
        WHERE primary_classification_groups.classification_id = classifications.id
          AND primary_classification_groups.deleted_at IS NULL
      );
    SQL
  end

  def down
  end
end
