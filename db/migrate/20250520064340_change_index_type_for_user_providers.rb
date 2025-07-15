# frozen_string_literal: true

class ChangeIndexTypeForUserProviders < ActiveRecord::Migration[7.1]
  def up
    remove_index :users, :providers, using: :gin
    add_index :users, :providers, using: :gin, opclass: { providers: :jsonb_path_ops }
  end

  def down
  end
end
