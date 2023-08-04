# frozen_string_literal: true

class FixClassificationAliasLinksAgain < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE VIEW classification_alias_links AS (
        WITH primary_classification_groups AS (
          SELECT DISTINCT classification_groups.classification_id,
            first_value(classification_groups.classification_alias_id) OVER (
              PARTITION BY classification_groups.classification_id
              ORDER BY classification_groups.created_at ASC
            ) AS classification_alias_id
          FROM classification_groups
          WHERE classification_groups.deleted_at IS NULL
        )
        SELECT additional_classification_groups.classification_alias_id AS parent_classification_alias_id,
          primary_classification_groups.classification_alias_id AS child_classification_alias_id,
          'related'::text AS link_type
        FROM (
            primary_classification_groups
            JOIN classification_groups additional_classification_groups ON primary_classification_groups.classification_id = additional_classification_groups.classification_id
            AND additional_classification_groups.classification_alias_id <> primary_classification_groups.classification_alias_id
            AND additional_classification_groups.deleted_at IS NULL
          )
        UNION
        SELECT classification_trees.parent_classification_alias_id,
          classification_trees.classification_alias_id AS child_classification_alias_id,
          'broader'::text AS link_type
        FROM classification_trees
        WHERE classification_trees.deleted_at IS NULL
      );
    SQL
  end

  def down
  end
end
