# frozen_string_literal: true

class AddReleaseToPersons < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        add_column :person_translations, :release, :jsonb
        add_column :person_translations, :release_id, :uuid
        add_column :person_translations, :release_comment, :text
      end

      dir.down do
        remove_column :person_translations, :release_comment
        remove_column :person_translations, :release_id
        remove_column :person_translations, :release
      end
    end
  end
end
