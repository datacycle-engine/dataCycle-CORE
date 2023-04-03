# frozen_string_literal: true

class AddApiUsersToWatchList < ActiveRecord::Migration[6.1]
  def change
    add_column :watch_lists, :api, :boolean, default: false
  end
end
