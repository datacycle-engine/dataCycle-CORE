# frozen_string_literal: true

class AddTemplateCreativeWork < ActiveRecord::Migration[5.0]
  def change
    add_column :creative_works, :template, :boolean, null: false, default: false
  end
end
