# frozen_string_literal: true

class ChangeIndexForThingTranslationsSlugToIncludeThingId < ActiveRecord::Migration[7.1]
  def change
    change_table :thing_translations, bulk: true do |t|
      # Remove the existing index on slug
      t.remove_index :slug if index_exists?(:thing_translations, :slug)

      # Add a new index on slug and thing_id
      t.index :slug, include: :thing_id, unique: true, name: 'index_thing_translations_on_slug_include_thing_id'
    end
  end
end
