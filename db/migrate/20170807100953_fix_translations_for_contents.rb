# frozen_string_literal: true

class FixTranslationsForContents < ActiveRecord::Migration[5.0]
  def up
    add_column :creative_work_translations, :headline, :text
    remove_column :creative_works, :headline
    add_column :creative_work_translations, :description, :text
    remove_column :creative_works, :description

    add_column :event_translations, :headline, :text
    remove_column :events, :headline
    add_column :event_translations, :description, :text
    remove_column :events, :description

    add_column :person_translations, :headline, :text
    remove_column :persons, :headline
    add_column :person_translations, :description, :text
    remove_column :persons, :description

    add_column :place_translations, :headline, :text
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
