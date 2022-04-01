# frozen_string_literal: true

class DestroyClassificationsWithoutPrimaryAlias < ActiveRecord::Migration[5.2]
  def up
    DataCycleCore::Classification.where('NOT EXISTS (SELECT FROM primary_classification_groups WHERE primary_classification_groups.classification_id = classifications.id AND primary_classification_groups.deleted_at IS NULL)').destroy_all
  end

  def down
  end
end
