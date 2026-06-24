# frozen_string_literal: true

class ValidateClassificationPolygonsConstraints < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;
      ALTER TABLE classification_polygons VALIDATE CONSTRAINT check_geom_validity;
      ALTER TABLE classification_polygons VALIDATE CONSTRAINT check_geom_type;
      ALTER TABLE classification_polygons VALIDATE CONSTRAINT check_geom_simple_validity;
      ALTER TABLE classification_polygons VALIDATE CONSTRAINT check_geom_simple_type;
    SQL
  rescue StandardError => e
    ActiveSupport::Notifications.instrument 'migration_failed.datacycle', {
      exception: e
    }
  end

  def down
  end
end
