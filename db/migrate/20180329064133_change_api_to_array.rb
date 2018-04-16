class ChangeApiToArray < ActiveRecord::Migration[5.0]
  def change
    add_column :stored_filters, :api_users, :text, array: true
  end
end
