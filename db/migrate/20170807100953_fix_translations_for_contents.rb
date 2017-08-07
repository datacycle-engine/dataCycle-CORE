class FixTranslationsForContents < ActiveRecord::Migration[5.0]
  def up
    DataCycleCore::CreativeWork.add_translation_fields! headline: :text   
    remove_column :creative_works, :headline
    DataCycleCore::CreativeWork.add_translation_fields! description: :text   
    remove_column :creative_works, :description

    DataCycleCore::Event.add_translation_fields! headline: :text   
    remove_column :events, :headline
    DataCycleCore::Event.add_translation_fields! description: :text   
    remove_column :events, :description

    DataCycleCore::Person.add_translation_fields! headline: :text   
    remove_column :persons, :headline
    DataCycleCore::Person.add_translation_fields! description: :text   
    remove_column :persons, :description

    DataCycleCore::Place.add_translation_fields! headline: :text   
    remove_column :places, :headline
  end

  def down
    remove_column :creative_work_translations, :headline
    add_column :creative_works, :headline, :text
    remove_column :creative_work_translations, :description
    add_column :creative_works, :description, :text

    remove_column :event_translations, :headline
    add_column :events, :headline, :text
    remove_column :event_translations, :description
    add_column :events, :description, :text

    remove_column :person_translations, :headline
    add_column :persons, :headline, :text
    remove_column :person_translations, :description
    add_column :persons, :description, :text

    remove_column :place_translations, :headline
    add_column :places, :headline, :text
  end
end
