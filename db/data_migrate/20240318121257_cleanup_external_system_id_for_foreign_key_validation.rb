# frozen_string_literal: true

class CleanupExternalSystemIdForForeignKeyValidation < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      DELETE FROM external_system_syncs
      WHERE NOT EXISTS (
          SELECT 1
          FROM external_systems
          WHERE external_systems.id = external_system_syncs.external_system_id
        );

      UPDATE things
      SET external_source_id = NULL,
        external_key = NULL
      WHERE things.external_source_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM external_systems
          WHERE external_systems.id = things.external_source_id
        );

      UPDATE thing_histories
      SET external_source_id = NULL,
        external_key = NULL
      WHERE thing_histories.external_source_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM external_systems
          WHERE external_systems.id = thing_histories.external_source_id
        );
    SQL

    validate_foreign_key :external_system_syncs, :external_systems
    validate_foreign_key :things, :external_systems
    validate_foreign_key :thing_histories, :external_systems
  end

  def down
  end
end
