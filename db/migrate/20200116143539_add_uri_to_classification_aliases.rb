# frozen_string_literal: true

class AddUriToClassificationAliases < ActiveRecord::Migration[5.2]
  def change
    add_column :classification_aliases, :uri, :string
    add_column :classifications, :uri, :string
    remove_column :classification_aliases, :internal_description, :string
  end
end
