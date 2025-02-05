# frozen_string_literal: true

class RebuildCccRelationsForRelationColumn < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
      execute <<-SQL.squish
        SET LOCAL statement_timeout = 0;

        SELECT public.generate_collected_cl_content_relations_transitive (array_agg(things.id))
        FROM things;
      SQL
    else
      execute <<-SQL.squish
        SET LOCAL statement_timeout = 0;

        SELECT public.generate_collected_classification_content_relations (array_agg(things.id), ARRAY[]::UUID[])
        FROM things;
      SQL
    end

    DataCycleCore::RunTaskJob.perform_later('db:maintenance:vacuum', [true, 'collected_classification_contents'])
  end

  def down
  end
end
