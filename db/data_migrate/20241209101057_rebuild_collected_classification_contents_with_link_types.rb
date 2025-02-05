# frozen_string_literal: true

class RebuildCollectedClassificationContentsWithLinkTypes < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    # don't run data_migration twice, as it will be run again later
    # if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
    #   execute <<-SQL.squish
    #     SET statement_timeout = 0;

    #     SELECT public.generate_collected_cl_content_relations_transitive (array_agg(things.id))
    #     FROM things;
    #   SQL
    # else
    #   execute <<-SQL.squish
    #     SET statement_timeout = 0;

    #     SELECT public.generate_collected_classification_content_relations (array_agg(things.id), ARRAY[]::UUID[])
    #     FROM things;
    #   SQL
    # end
  end

  def down
  end
end
