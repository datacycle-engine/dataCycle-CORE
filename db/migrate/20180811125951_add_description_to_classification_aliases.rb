# frozen_string_literal: true

class AddDescriptionToClassificationAliases < ActiveRecord::Migration[5.1]
  def change
    add_column :classification_aliases, :description, :string
  end
end
