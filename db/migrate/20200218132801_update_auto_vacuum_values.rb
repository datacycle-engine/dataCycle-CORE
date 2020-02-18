# frozen_string_literal: true

class UpdateAutoVacuumValues < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      ALTER TABLE activities SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE asset_contents SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE classification_contents SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE classification_content_histories SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE content_contents SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE content_content_histories SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE searches SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE stored_filters SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE thing_histories SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE thing_history_translations SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE thing_translations SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
      ALTER TABLE things SET (autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0.0, autovacuum_analyze_threshold = 100);
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE activities SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE asset_contents SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE classification_contents SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE classification_content_histories SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE content_contents SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE content_content_histories SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE searches SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE stored_filters SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE thing_histories SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE thing_history_translations SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE thing_translations SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
      ALTER TABLE things SET (autovacuum_vacuum_scale_factor = 0.2, autovacuum_vacuum_threshold = 50, autovacuum_analyze_scale_factor = 0.1, autovacuum_analyze_threshold = 50);
    SQL
  end
end
