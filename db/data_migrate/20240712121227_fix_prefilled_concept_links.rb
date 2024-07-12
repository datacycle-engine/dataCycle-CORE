# frozen_string_literal: true

class FixPrefilledConceptLinks < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      DELETE FROM concept_links
      WHERE concept_links.id IN (
          SELECT cl.id
          FROM concept_links cl
            JOIN concepts c2 ON c2.id = cl.child_id
          WHERE cl.link_type = 'related'
            AND NOT EXISTS (
              SELECT 1
              FROM classification_groups cg
              WHERE cg.deleted_at IS NULL
                AND cg.classification_alias_id = cl.parent_id
                AND cg.classification_id = c2.classification_id
            )
        );

      DELETE FROM concept_links
      WHERE concept_links.id IN (
          SELECT cl.id
          FROM concept_links cl
            JOIN concepts c2 ON c2.id = cl.child_id
          WHERE cl.link_type = 'broader'
            AND NOT EXISTS (
              SELECT 1
              FROM classification_trees ct
              WHERE ct.deleted_at IS NULL
                AND ct.classification_alias_id = cl.child_id
                AND ct.parent_classification_alias_id IS NOT DISTINCT
              FROM cl.parent_id
            )
        );

      UPDATE concept_links
      SET id = fixed_ids.cg_id
      FROM (
          SELECT cl.id AS cl_id,
            cg.id AS cg_id
          FROM concept_links cl
            JOIN concepts c2 ON c2.id = cl.child_id
            JOIN classification_groups cg ON cg.classification_alias_id = cl.parent_id
            AND cg.classification_id = c2.classification_id
            AND cg.deleted_at IS NULL
          WHERE cl.link_type = 'related'
            AND cg.id != cl.id
        ) AS fixed_ids
      WHERE fixed_ids.cl_id = concept_links.id;

      UPDATE concept_links
      SET id = fixed_ids.ct_id
      FROM (
          SELECT cl.id AS cl_id,
            ct.id AS ct_id
          FROM concept_links cl
            JOIN classification_trees ct ON ct.classification_alias_id = cl.child_id
            AND ct.parent_classification_alias_id = cl.parent_id
            AND ct.deleted_at IS NULL
          WHERE cl.link_type = 'broader'
            AND ct.id != cl.id
        ) AS fixed_ids
      WHERE fixed_ids.cl_id = concept_links.id;
    SQL
  end

  def down
  end
end
