# frozen_string_literal: true

class ChangeWatchListHeadlineToName < ActiveRecord::Migration[5.1]
  def change
    rename_column :watch_lists, :headline, :name
  end
end
