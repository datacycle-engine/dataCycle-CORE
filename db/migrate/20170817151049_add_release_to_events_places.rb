# frozen_string_literal: true

class AddReleaseToEventsPlaces < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        add_column :event_translations, :release, :jsonb
        add_column :place_translations, :release, :jsonb
      end

      dir.down do
        remove_column :place_translations, :release
        remove_column :event_translations, :release
      end
    end
  end
end
