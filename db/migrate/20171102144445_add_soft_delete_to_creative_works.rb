class AddSoftDeleteToCreativeWorks < ActiveRecord::Migration[5.0]
  def change
    add_column :creative_works, :deleted_at, :datetime
    add_index :creative_works, :deleted_at
  end
end
