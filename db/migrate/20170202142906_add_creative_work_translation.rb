class AddCreativeWorkTranslation < ActiveRecord::Migration[5.0]
  def up
    create_table :creative_work_translations do |t|
      t.uuid :creative_work_id
      t.string :locale
      t.jsonb :content
      t.jsonb :properties
    end
    add_column :creative_works, :external_source_id, :uuid
  end

  def down
    remove_column :creative_works, :external_source_id, :uuid
    drop_table :creative_work_translations
  end
end
