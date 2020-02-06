# frozen_string_literal: true

class UpdateIndexesForThingsAndSearch < ActiveRecord::Migration[5.2]
  def up
    # remove obsolete columns
    remove_column :searches, :classification_mapping

    execute <<-SQL
      DROP INDEX IF EXISTS index_things_on_template_content_type;
      CREATE INDEX IF NOT EXISTS index_things_on_template_content_type_validity_range ON things (id, template, content_type, validity_range, template_name);
    SQL

    add_column :searches, :classification_aliases_mapping, :uuid, array: true
    add_column :searches, :classification_ancestors_mapping, :uuid, array: true

    add_index :searches, :classification_aliases_mapping, using: :gin
    add_index :searches, :classification_ancestors_mapping, using: :gin
  end

  def down
    add_column :searches, :classification_mapping, :jsonb
    add_index :searches, :classification_mapping, using: :gin

    execute <<-SQL
      DROP INDEX IF EXISTS index_things_on_template_content_type_validity_range;
      CREATE INDEX IF NOT EXISTS index_things_on_template_content_type ON things (template, content_type);
    SQL

    remove_column :searches, :classification_aliases_mapping
    remove_column :searches, :classification_ancestors_mapping

    remove_index :searches, :classification_aliases_mapping, using: :gin
    remove_index :searches, :classification_ancestors_mapping, using: :gin
  end
end
