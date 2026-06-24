# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TransitiveClassificationPath < Base
      class << self
        def update_triggers(update_jobs = true)
          return unless ActiveRecord::Base.connection.table_exists?('classification_alias_paths_transitive')

          transitive_triggers = enabled? ? 'ENABLE' : 'DISABLE'
          non_transitive_triggers = enabled? ? 'DISABLE' : 'ENABLE'

          ActiveRecord::Base.connection.execute <<~SQL.squish
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
            ALTER TABLE concept_links #{non_transitive_triggers} TRIGGER delete_concept_links_ccc_relations_trigger_1;
            ALTER TABLE concept_links #{non_transitive_triggers} TRIGGER generate_concept_links_ccc_relations_trigger_4;
            ALTER TABLE concept_links #{non_transitive_triggers} TRIGGER update_concept_links_ccc_relations_trigger_4;
          SQL

          DataCycleCore::RebuildClassificationMappingsJob.perform_later if update_jobs
        rescue ActiveRecord::NoDatabaseError
          nil
        end

        def rebuild_transitive_tables!
          if enabled?
            ActiveRecord::Base.connection.execute <<~SQL.squish
              SET LOCAL statement_timeout = 0;
              SELECT public.upsert_ca_paths_transitive (ARRAY_AGG(id)) FROM concepts;
            SQL
          else
            ActiveRecord::Base.connection.execute <<~SQL.squish
              SET LOCAL statement_timeout = 0;
              SELECT public.upsert_ca_paths (ARRAY_AGG(id)) FROM concepts;
            SQL
          end

          rebuild_ccc!

          return if Rails.env.test?

          DataCycleCore::RunTaskJob.perform_later('db:maintenance:vacuum', [true, 'classification_alias_paths|classification_alias_paths_transitive|collected_classification_contents'])
        end

        def rebuild_ccc!
          if enabled?
            ActiveRecord::Base.connection.execute <<~SQL.squish
              SET LOCAL statement_timeout = 0;
              SELECT public.generate_collected_cl_content_relations_transitive (array_agg(things.id))
              FROM things;
            SQL
          else
            ActiveRecord::Base.connection.execute <<~SQL.squish
              SET LOCAL statement_timeout = 0;
              SELECT public.generate_collected_classification_content_relations (array_agg(things.id), ARRAY[]::UUID[])
              FROM things;
            SQL
          end
        end
      end
    end
  end
end
