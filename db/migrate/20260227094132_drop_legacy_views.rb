# frozen_string_literal: true

class DropLegacyViews < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DROP VIEW IF EXISTS content_content_relations;
      DROP VIEW IF EXISTS classification_alias_links;
      DROP VIEW IF EXISTS content_meta_items;
    SQL
  end

  def down
  end
end
