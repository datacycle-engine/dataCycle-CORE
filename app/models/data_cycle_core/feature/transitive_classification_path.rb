# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TransitiveClassificationPath < Base
      class << self
        def update_triggers(update_jobs = true)
          return unless ActiveRecord::Base.connection.table_exists?('classification_alias_paths_transitive')

          transitive_triggers = enabled? ? 'ENABLE' : 'DISABLE'
          non_transitive_triggers = enabled? ? 'DISABLE' : 'ENABLE'

          ActiveRecord::Base.connection.execute <<-SQL.squish
            ALTER TABLE classification_alias_paths_transitive #{transitive_triggers} TRIGGER generate_ccc_relations_transitive_trigger;
            ALTER TABLE classification_alias_paths_transitive #{transitive_triggers} TRIGGER delete_ccc_relations_transitive_trigger;
            ALTER TABLE classification_contents #{transitive_triggers} TRIGGER delete_ccc_relations_transitive_trigger;
            ALTER TABLE classification_contents #{transitive_triggers} TRIGGER generate_ccc_relations_transitive_trigger;
            ALTER TABLE classification_contents #{transitive_triggers} TRIGGER update_ccc_relations_transitive_trigger;
            ALTER TABLE concept_schemes #{transitive_triggers} TRIGGER concept_schemes_update_transitive_paths_trigger;
            ALTER TABLE concepts #{transitive_triggers} TRIGGER concepts_create_transitive_paths_trigger;
            ALTER TABLE concepts #{transitive_triggers} TRIGGER concepts_update_transitive_paths_trigger;
            ALTER TABLE concepts #{transitive_triggers} TRIGGER concepts_delete_transitive_paths_trigger;
            ALTER TABLE concept_links #{transitive_triggers} TRIGGER concept_links_create_transitive_paths_trigger;
            ALTER TABLE concept_links #{transitive_triggers} TRIGGER concept_links_update_transitive_paths_trigger;
            ALTER TABLE concept_links #{transitive_triggers} TRIGGER concept_links_delete_transitive_paths_trigger;

            ALTER TABLE classification_alias_paths #{non_transitive_triggers} TRIGGER generate_collected_classification_content_relations_trigger;
            ALTER TABLE classification_alias_paths #{non_transitive_triggers} TRIGGER update_collected_classification_content_relations_trigger;
            ALTER TABLE classification_contents #{non_transitive_triggers} TRIGGER generate_collected_classification_content_relations_trigger_1;
            ALTER TABLE classification_contents #{non_transitive_triggers} TRIGGER generate_collected_classification_content_relations_trigger_2;
            ALTER TABLE classification_contents #{non_transitive_triggers} TRIGGER update_collected_classification_content_relations_trigger_1;
            ALTER TABLE classification_groups #{non_transitive_triggers} TRIGGER delete_collected_classification_content_relations_trigger_1;
            ALTER TABLE classification_groups #{non_transitive_triggers} TRIGGER generate_collected_classification_content_relations_trigger_4;
            ALTER TABLE classification_groups #{non_transitive_triggers} TRIGGER update_ccc_relations_trigger_4;
            ALTER TABLE classification_groups #{non_transitive_triggers} TRIGGER update_deleted_at_ccc_relations_trigger_4;
          SQL

          DataCycleCore::RebuildClassificationMappingsJob.perform_later if update_jobs
        rescue ActiveRecord::NoDatabaseError
          nil
        end
      end
    end
  end
end
