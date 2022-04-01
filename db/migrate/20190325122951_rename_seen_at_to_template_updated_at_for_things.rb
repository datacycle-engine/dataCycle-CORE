# frozen_string_literal: true

class RenameSeenAtToTemplateUpdatedAtForThings < ActiveRecord::Migration[5.1]
  def change
    rename_column :things, :seen_at, :template_updated_at
    rename_column :thing_histories, :seen_at, :template_updated_at
  end
end
