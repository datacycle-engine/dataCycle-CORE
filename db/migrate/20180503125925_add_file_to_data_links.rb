class AddFileToDataLinks < ActiveRecord::Migration[5.0]
  def change
    add_column :data_links, :file, :string
  end
end
