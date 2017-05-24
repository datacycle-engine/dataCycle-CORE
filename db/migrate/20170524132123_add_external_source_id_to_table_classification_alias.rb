class AddExternalSourceIdToTableClassificationAlias < ActiveRecord::Migration[5.0]
  def change
    add_column :classification_aliases, :external_source_id, :uuid
  end
end
