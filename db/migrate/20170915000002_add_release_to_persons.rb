class AddReleaseToPersons < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        DataCycleCore::Person.add_translation_fields! release: :jsonb
        DataCycleCore::Person.add_translation_fields! release_id: :uuid
        DataCycleCore::Person.add_translation_fields! release_comment: :text
      end

      dir.down do
        remove_column :person_translations, :release_comment
        remove_column :person_translations, :release_id
        remove_column :person_translations, :release
      end
    end
  end
end
