# frozen_string_literal: true

class AddDescriptionToCollectionConfigurations < ActiveRecord::Migration[6.1]
  def change
    add_column(:collection_configurations, :description, :text)
    add_index(:collection_configurations, :description)
  end
end
