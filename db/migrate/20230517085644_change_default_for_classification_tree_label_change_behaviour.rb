# frozen_string_literal: true

class ChangeDefaultForClassificationTreeLabelChangeBehaviour < ActiveRecord::Migration[6.1]
  def change
    change_column_default :classification_tree_labels, :change_behaviour, from: ['trigger_webhooks', 'clear_cache'], to: ['trigger_webhooks']
  end
end
