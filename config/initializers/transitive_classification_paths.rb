# frozen_string_literal: true

# switch active triggers according to configuration
Rails.application.configure do
  config.after_initialize do
    next unless ActiveRecord::Base.connection.table_exists?('classification_alias_paths_transitive')

    result = ActiveRecord::Base.connection.execute <<-SQL.squish
      SELECT
        tgenabled
      FROM
        pg_trigger
      WHERE
        tgname IN ('delete_ccc_relations_transitive_trigger', 'generate_ccc_relations_transitive_trigger', 'update_ccc_relations_transitive_trigger');
    SQL

    transitive_disabled_before = result.values.all? { |v| v.first.to_s.casecmp('d').zero? } # transitive triggers disabled
    transitive_config_changed = DataCycleCore.transitive_classification_paths == transitive_disabled_before

    next unless transitive_config_changed

    transitive_triggers = DataCycleCore.transitive_classification_paths ? 'ENABLE' : 'DISABLE'
    non_transitive_triggers = DataCycleCore.transitive_classification_paths ? 'DISABLE' : 'ENABLE'

    ActiveRecord::Base.connection.execute <<-SQL.squish
      ALTER TABLE classification_alias_paths_transitive #{transitive_triggers} TRIGGER generate_ccc_relations_transitive_trigger;
      ALTER TABLE classification_alias_paths_transitive #{transitive_triggers} TRIGGER update_ccc_relations_transitive_trigger;
      ALTER TABLE classification_contents #{transitive_triggers} TRIGGER delete_ccc_relations_transitive_trigger;
      ALTER TABLE classification_contents #{transitive_triggers} TRIGGER generate_ccc_relations_transitive_trigger;
      ALTER TABLE classification_contents #{transitive_triggers} TRIGGER update_ccc_relations_transitive_trigger;
      ALTER TABLE classification_groups #{transitive_triggers} TRIGGER delete_ccc_relations_transitive_trigger;
      ALTER TABLE classification_groups #{transitive_triggers} TRIGGER generate_ccc_relations_transitive_trigger;
      ALTER TABLE classification_groups #{transitive_triggers} TRIGGER update_ccc_relations_transitive_trigger;

      ALTER TABLE classification_alias_paths #{non_transitive_triggers} TRIGGER generate_collected_classification_content_relations_trigger;
      ALTER TABLE classification_contents #{non_transitive_triggers} TRIGGER generate_collected_classification_content_relations_trigger_1;
      ALTER TABLE classification_contents #{non_transitive_triggers} TRIGGER generate_collected_classification_content_relations_trigger_2;
      ALTER TABLE classification_contents #{non_transitive_triggers} TRIGGER update_collected_classification_content_relations_trigger_1;
      ALTER TABLE classification_groups #{non_transitive_triggers} TRIGGER delete_collected_classification_content_relations_trigger_1;
      ALTER TABLE classification_groups #{non_transitive_triggers} TRIGGER generate_collected_classification_content_relations_trigger_4;
      ALTER TABLE classification_groups #{non_transitive_triggers} TRIGGER update_collected_classification_content_relations_trigger_4;
    SQL

    DataCycleCore::RunTaskJob.set(queue: 'default').perform_later('db:configure:rebuild_ccc_relations')
  end
end
