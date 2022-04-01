# frozen_string_literal: true

class AddPhotoToPlace < ActiveRecord::Migration[5.0]
  def change
    add_column :places, :photo, :uuid
  end
end
