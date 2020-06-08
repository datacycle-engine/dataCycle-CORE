# frozen_string_literal: true

class AddRelationToClassificationContent < ActiveRecord::Migration[5.0]
  def change
    add_column :classification_contents, :relation, :string
    add_column :classification_content_histories, :relation, :string
  end
end
