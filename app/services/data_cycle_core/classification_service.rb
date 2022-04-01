# frozen_string_literal: true

module DataCycleCore
  class ClassificationService
    def self.visible_classification_tree?(tree_label, scopes)
      tree_label_visibility = Rails.cache.fetch("#{tree_label}_visibilty", expires_in: 5.minutes) { Array(DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label)&.visibility) }
      (tree_label_visibility & Array(scopes)).size.positive?
    end

    def self.update_transitive_trigger_status
      return unless ActiveRecord::Base.connection.table_exists?('classification_alias_paths_transitive')

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

      return unless transitive_config_changed

      transitive_triggers = DataCycleCore.transitive_classification_paths ? 'ENABLE' : 'DISABLE'
      non_transitive_triggers = DataCycleCore.transitive_classification_paths ? 'DISABLE' : 'ENABLE'

      ActiveRecord::Base.connection.execute <<-SQL.squish
        ALTER TABLE classification_alias_paths_transitive #{transitive_triggers} TRIGGER generate_ccc_relations_transitive_trigger;
        ALTER TABLE classification_alias_paths_transitive #{transitive_triggers} TRIGGER delete_ccc_relations_transitive_trigger;
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

      DataCycleCore::RunTaskJob.perform_later(DataCycleCore.transitive_classification_paths ? 'db:configure:rebuild_cap_transitive' : 'db:configure:rebuild_ca_paths')
      DataCycleCore::RunTaskJob.perform_later('db:configure:rebuild_ccc_relations')
    rescue ActiveRecord::NoDatabaseError
      nil
    end
  end
end
