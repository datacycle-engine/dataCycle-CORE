# frozen_string_literal: true

class AddStatusTable < ActiveRecord::Migration[5.0]
  def change
    create_table :releases, id: :uuid do |t|
      t.integer :release_code
      t.string :release_text
    end

    reversible do |dir|
      dir.up do
        add_column :creative_work_translations, :release, :jsonb
      end

      dir.down do
        remove_column :creative_work_translations, :release
      end
    end
  end
end
