# frozen_string_literal: true

class AddClassificationChangeBehaviourToClassificationTreeLabels < ActiveRecord::Migration[5.2]
  def change
    add_column :classification_tree_labels, :change_behaviour, :string, array: true, default: DataCycleCore.classification_change_behaviour
  end
end
