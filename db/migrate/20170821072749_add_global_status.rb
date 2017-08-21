class AddGlobalStatus < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        DataCycleCore::CreativeWork.add_translation_fields! release_id: :uuid
        DataCycleCore::CreativeWork.add_translation_fields! release_comment: :text
        DataCycleCore::Event.add_translation_fields! release_id: :uuid
        DataCycleCore::Event.add_translation_fields! release_comment: :text
        DataCycleCore::Place.add_translation_fields! release_id: :uuid
        DataCycleCore::Place.add_translation_fields! release_comment: :text
      end

      dir.down do
        remove_column :place_translations, :release_id, :release_comment
        remove_column :event_translations, :release_id, :release_comment
        remove_column :creative_work_translations, :release_id, :release_comment
      end
    end
  end
end
