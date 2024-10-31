# frozen_string_literal: true

class RemoveReleaseFromTables < ActiveRecord::Migration[5.1]
  def up
    ['creative_works', 'events', 'persons', 'places', 'organizations'].map(&:singularize).each do |table|
      remove_columns :"#{table}_translations", :release_comment, :release_id, :release
      remove_columns :"#{table}_history_translations", :release_comment, :release_id, :release
    end

    drop_table :releases, if_exists: true
  end

  def down
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    create_table :releases, id: :uuid do |t|
      t.integer :release_code
      t.string :release_text
    end

    ['creative_works', 'events', 'persons', 'places', 'organizations'].map(&:singularize).each do |table|
      add_column :"#{table}_translations", :release, :jsonb
      add_column :"#{table}_translations", :release_id, :uuid
      add_column :"#{table}_translations", :release_comment, :text
      add_column :"#{table}_history_translations", :release, :jsonb
      add_column :"#{table}_history_translations", :release_id, :uuid
      add_column :"#{table}_history_translations", :release_comment, :text
    end
  end
end
