class AddEmbeddedAttributesToSearch < ActiveRecord::Migration[5.2]
  def change
    add_column :searches, :embedded_attributes, :jsonb
  end
end
