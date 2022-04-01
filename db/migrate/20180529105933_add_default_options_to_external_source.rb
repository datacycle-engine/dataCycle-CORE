# frozen_string_literal: true

class AddDefaultOptionsToExternalSource < ActiveRecord::Migration[5.0]
  def change
    add_column :external_sources, :default_options, :jsonb
  end
end
