# frozen_string_literal: true

class AddExternalKeyColumnForContents < ActiveRecord::Migration[5.0]
  def up
    add_column :creative_works, :external_key, :string

    add_column :persons, :external_key, :string

    add_column :events, :external_key, :string
  end

  def down
    remove_column :creative_works, :external_key

    remove_column :persons, :external_key

    remove_column :events, :external_key
  end
end
