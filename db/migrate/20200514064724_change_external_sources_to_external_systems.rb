# frozen_string_literal: true

class ChangeExternalSourcesToExternalSystems < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/BulkChangeTable
  def up
    add_column :external_systems, :last_download, :datetime
    add_column :external_systems, :last_successful_download, :datetime
    add_column :external_systems, :last_import, :datetime
    add_column :external_systems, :last_successful_import, :datetime

    execute <<-SQL
      INSERT INTO external_systems(id, name, config, credentials, default_options, last_download, last_successful_download, last_import, last_successful_import, identifier, created_at, updated_at)
      SELECT id, name, config, credentials, default_options, last_download, last_successful_download, last_import, last_successful_import, identifier, NOW(), NOW() FROM external_sources
      ON CONFLICT (id)
      DO UPDATE
      SET name = EXCLUDED.name;
    SQL

    execute <<~SQL
      UPDATE
        external_system_syncs
      SET
        external_system_id = new_system.new_id
      FROM (
        SELECT
          external_systems.id AS old_id,
          s.id AS new_id
        FROM
          external_systems
          INNER JOIN external_systems s ON s.name = external_systems.name
            AND NOT s.config ? 'push_config'
            AND external_systems.id != s.id
        WHERE
          external_systems.config ? 'push_config') AS new_system
      WHERE
        external_system_syncs.external_system_id = new_system.old_id
    SQL

    execute <<-SQL
      DELETE FROM external_systems
      WHERE NOT external_systems.config ? 'import_config'
      AND EXISTS (
        SELECT FROM external_systems s
        WHERE external_systems.name = s.name
        AND external_systems.id != s.id
      )
    SQL

    drop_table :external_sources
  end

  def down
    create_table :external_sources, id: :uuid do |t|
      t.string :name
      t.jsonb  :credentials
      t.jsonb  :config
      t.jsonb :default_options
      t.datetime  :last_download
      t.datetime  :last_successful_download
      t.datetime  :last_import
      t.datetime  :last_successful_import
      t.string :identifier
      t.index ['id'], name: 'index_external_sources_on_id', unique: true, using: :btree
    end

    execute <<-SQL
      INSERT INTO external_sources(id, name, config, credentials, default_options, last_download, last_successful_download, last_import, last_successful_import, identifier)
      SELECT id, name, config, credentials, default_options, last_download, last_successful_download, last_import, last_successful_import, identifier FROM external_systems
      WHERE external_systems.config ? 'import_config'
      OR external_systems.config IS NULL
    SQL

    execute <<-SQL
      DELETE FROM external_systems
      WHERE NOT external_systems.config ? 'export_config'
      OR external_systems.config IS NULL
    SQL

    remove_column :external_systems, :last_download
    remove_column :external_systems, :last_successful_download
    remove_column :external_systems, :last_import
    remove_column :external_systems, :last_successful_import
  end
  # rubocop:enable Rails/BulkChangeTable
end
