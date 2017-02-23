class AddCreativeWorkTranslation < ActiveRecord::Migration[5.0]
  def up
    CreativeWork.create_translation_table!({
      content: :jsonb,
      properties: :jsonb
    })
    add_column :creative_works, :external_source_id, :uuid
  end

  def down
    remove_column :creative_works, :external_source_id, :uuid
    CreativeWork.drop_translation_table!
  end
end
