# frozen_string_literal: true

class AddUiConfigsForClassificationAliases < ActiveRecord::Migration[6.1]
  def change
    add_column :classification_aliases, :ui_configs, :jsonb
  end
end
