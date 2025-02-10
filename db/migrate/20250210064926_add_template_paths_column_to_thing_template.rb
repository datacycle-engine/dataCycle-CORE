# frozen_string_literal: true

class AddTemplatePathsColumnToThingTemplate < ActiveRecord::Migration[7.1]
  def change
    add_column :thing_templates, :template_paths, :string, array: true, default: []
  end
end
