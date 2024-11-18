# frozen_string_literal: true

class FixConceptLinksIds < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      SET statement_timeout = 0;

      UPDATE concept_links
      SET id = ct.id,
        parent_id = ct.parent_classification_alias_id
      FROM classification_trees ct
      WHERE concept_links.child_id = ct.classification_alias_id
        AND concept_links.link_type = 'broader'
        AND ct.deleted_at IS NULL
        AND (
          ct.parent_classification_alias_id IS DISTINCT
          FROM concept_links.parent_id
            OR ct.id IS DISTINCT
          FROM concept_links.id
        );
    SQL
  end

  def down
  end
end
