# frozen_string_literal: true

class AddRepresentationOfToThings < ActiveRecord::Migration[5.1]
  def change
    add_reference :things, :representation_of, references: :users, index: true, type: :uuid
  end
end
