# frozen_string_literal: true

class AddSlugToThingTranslations < ActiveRecord::Migration[5.2]
  def change
    add_column :thing_translations, :slug, :string
    add_index :thing_translations, :slug, unique: true
    add_column :thing_history_translations, :slug, :string

    DataCycleCore::Thing::Translation.connection.schema_cache.clear!
    DataCycleCore::Thing::Translation.reset_column_information
    DataCycleCore::Thing::History::Translation.connection.schema_cache.clear!
    DataCycleCore::Thing::History::Translation.reset_column_information
  end
end
