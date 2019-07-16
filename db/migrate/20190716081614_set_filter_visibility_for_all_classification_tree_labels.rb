# frozen_string_literal: true

class SetFilterVisibilityForAllClassificationTreeLabels < ActiveRecord::Migration[5.2]
  def up
    DataCycleCore::ClassificationTreeLabel.find_each do |tree_label|
      next if DataCycleCore.features.dig(:advanced_filter, :classification_alias_ids).is_a?(Array) && DataCycleCore.features.dig(:advanced_filter, :classification_alias_ids).exclude?(tree_label.name)
      tree_label.update_column(:visibility, tree_label.visibility.push('filter').uniq)
    end
  end

  def down
    DataCycleCore::ClassificationTreeLabel.find_each do |tree_label|
      tree_label.update_column(:visibility, tree_label.visibility.except('filter'))
    end
  end
end
