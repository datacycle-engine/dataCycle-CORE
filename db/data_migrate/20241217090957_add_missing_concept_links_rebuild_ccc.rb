# frozen_string_literal: true

class AddMissingConceptLinksRebuildCcc < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      SET statement_timeout = 0;

      INSERT INTO concept_links(parent_id, child_id, link_type)
      SELECT NULL AS "parent_id",
        concepts.id AS "child_id",
        'broader' AS "link_type"
      FROM concepts
      WHERE NOT EXISTS (
          SELECT 1
          FROM concept_links cl
          WHERE cl.child_id = concepts.id
            AND cl.link_type = 'broader'
        );
    SQL

    if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
      execute <<-SQL.squish
        SET statement_timeout = 0;

        SELECT public.generate_collected_cl_content_relations_transitive (array_agg(things.id))
        FROM things;
      SQL
    else
      execute <<-SQL.squish
        SET statement_timeout = 0;

        SELECT public.generate_collected_classification_content_relations (array_agg(things.id), ARRAY[]::UUID[])
        FROM things;
      SQL
    end
  end

  def down
  end
end
