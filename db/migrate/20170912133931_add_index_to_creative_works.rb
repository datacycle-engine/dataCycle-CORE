# frozen_string_literal: true

class AddIndexToCreativeWorks < ActiveRecord::Migration[5.0]
  def change
    add_index :creative_works, "(metadata #>> '{ validation, name }')", name: 'index_creative_works_on_metadata_validation_name'
  end
end
