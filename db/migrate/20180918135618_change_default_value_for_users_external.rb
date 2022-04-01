# frozen_string_literal: true

class ChangeDefaultValueForUsersExternal < ActiveRecord::Migration[5.1]
  def up
    change_column_default(:users, :external, false)
  end

  def down
    change_column_default(:users, :external, true)
  end
end
