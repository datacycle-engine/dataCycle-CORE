# frozen_string_literal: true

class AddGlobalStatus < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        add_column :creative_work_translations, :release_id, :uuid
        add_column :creative_work_translations, :release_comment, :text
        add_column :event_translations, :release_id, :uuid
        add_column :event_translations, :release_comment, :text
        add_column :place_translations, :release_id, :uuid
        add_column :place_translations, :release_comment, :text
      end

      dir.down do
        remove_column :place_translations, :release_id, :release_comment
        remove_column :event_translations, :release_id, :release_comment
        remove_column :creative_work_translations, :release_id, :release_comment
      end
    end
  end
end
