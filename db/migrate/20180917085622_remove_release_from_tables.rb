# frozen_string_literal: true

class RemoveReleaseFromTables < ActiveRecord::Migration[5.1]
  def up
    (DataCycleCore.content_tables - ['things'] + ['organizations']).map(&:singularize).each do |table|
      remove_columns "#{table}_translations".to_sym, :release_comment, :release_id, :release
      remove_columns "#{table}_history_translations".to_sym, :release_comment, :release_id, :release
    end

    drop_table :releases, if_exists: true
  end

  def down
    create_table :releases, id: :uuid do |t|
      t.integer :release_code
      t.string :release_text
    end

    (DataCycleCore.content_tables - ['things'] + ['organizations']).map(&:singularize).each do |table|
      add_column "#{table}_translations".to_sym, :release, :jsonb
      add_column "#{table}_translations".to_sym, :release_id, :uuid
      add_column "#{table}_translations".to_sym, :release_comment, :text
      add_column "#{table}_history_translations".to_sym, :release, :jsonb
      add_column "#{table}_history_translations".to_sym, :release_id, :uuid
      add_column "#{table}_history_translations".to_sym, :release_comment, :text
    end
  end
end
