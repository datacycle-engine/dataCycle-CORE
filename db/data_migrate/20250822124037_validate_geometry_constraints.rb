# frozen_string_literal: true

class ValidateGeometryConstraints < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;
      ALTER TABLE geometries VALIDATE CONSTRAINT check_geom_validity;
      ALTER TABLE geometries VALIDATE CONSTRAINT check_geom_type;
      ALTER TABLE geometries VALIDATE CONSTRAINT check_geom_simple_validity;
      ALTER TABLE geometries VALIDATE CONSTRAINT check_geom_simple_type;
    SQL
  rescue StandardError => e
    ActiveSupport::Notifications.instrument 'migration_failed.datacycle', {
      exception: e
    }
  end

  def down
  end
end
