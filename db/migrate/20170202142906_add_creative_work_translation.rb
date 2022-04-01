# frozen_string_literal: true

class AddCreativeWorkTranslation < ActiveRecord::Migration[5.0]
  def up
    create_table :creative_work_translations do |t|
      t.uuid :creative_work_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.jsonb :properties
      t.timestamps
    end
    add_column :creative_works, :external_source_id, :uuid
  end

  def down
    remove_column :creative_works, :external_source_id, :uuid
    drop_table :creative_work_translations
  end
end
