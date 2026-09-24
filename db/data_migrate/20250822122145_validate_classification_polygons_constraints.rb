# frozen_string_literal: true

# Written against classification_polygons, then ported by #41458 to whichever of the two tables holds
# the polygons in the schema it finds: the cut renamed the table to concept_polygons and carried the
# four NOT VALID constraints over unvalidated, so skipping here would leave a post-cut database with
# constraints an upgraded one has validated.
class ValidateClassificationPolygonsConstraints < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    table = table_exists?(:classification_polygons) ? 'classification_polygons' : 'concept_polygons'

    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;
      ALTER TABLE #{table} VALIDATE CONSTRAINT check_geom_validity;
      ALTER TABLE #{table} VALIDATE CONSTRAINT check_geom_type;
      ALTER TABLE #{table} VALIDATE CONSTRAINT check_geom_simple_validity;
      ALTER TABLE #{table} VALIDATE CONSTRAINT check_geom_simple_type;
    SQL
  rescue StandardError => e
    ActiveSupport::Notifications.instrument 'migration_failed.datacycle', {
      exception: e
    }
  end

  def down
  end
end
