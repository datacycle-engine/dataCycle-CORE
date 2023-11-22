# frozen_string_literal: true

class ModifyForeignKeyConstraintOnExternalHashes < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE external_hashes DROP CONSTRAINT fk_external_hashes_things;

      ALTER TABLE external_hashes
      ADD CONSTRAINT fk_external_hashes_things FOREIGN KEY (external_source_id, external_key) REFERENCES things (external_source_id, external_key) ON DELETE CASCADE ON UPDATE CASCADE NOT VALID;
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE external_hashes DROP CONSTRAINT fk_external_hashes_things;

      ALTER TABLE external_hashes
      ADD CONSTRAINT fk_external_hashes_things FOREIGN KEY (external_source_id, external_key) REFERENCES things (external_source_id, external_key) ON DELETE CASCADE NOT VALID;
    SQL
  end
end
