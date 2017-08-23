class AddReleaseToEventsPlaces < ActiveRecord::Migration[5.0]
  def change

    reversible do |dir|
      dir.up do
        DataCycleCore::Event.add_translation_fields! release: :jsonb
        DataCycleCore::Place.add_translation_fields! release: :jsonb
      end

      dir.down do
        remove_column :place_translations, :release
        remove_column :event_translations, :release
      end
    end

  end
end
