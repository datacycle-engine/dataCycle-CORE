# frozen_string_literal: true

class FixClassificationsForOutdoorActiveSystemKategorien < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE
        classification_aliases
      SET
        internal_name = trim(classification_aliases.internal_name),
        name_i18n = (classification_aliases.name_i18n - 'de') || jsonb_build_object('de',
          trim(classification_aliases.name_i18n ->> 'de'))
      WHERE
        classification_aliases.id IN (
          SELECT
            classification_aliases.id
          FROM
            classification_aliases
            INNER JOIN classification_trees ON classification_trees.deleted_at IS NULL
              AND classification_trees.classification_alias_id = classification_aliases.id
            INNER JOIN classification_tree_labels ON classification_tree_labels.deleted_at IS NULL
              AND classification_tree_labels.id = classification_trees.classification_tree_label_id
          WHERE
            classification_aliases.deleted_at IS NULL
            AND classification_tree_labels.name ILIKE 'OutdoorActive - %');

      UPDATE
        classifications
      SET
        name = trim(classifications.name)
      WHERE
        classifications.id IN (
          SELECT
            classifications.id
          FROM
            classifications
            INNER JOIN primary_classification_groups ON primary_classification_groups.deleted_at IS NULL
              AND primary_classification_groups.classification_id = classifications.id
            INNER JOIN classification_aliases ON classification_aliases.deleted_at IS NULL
              AND classification_aliases.id = primary_classification_groups.classification_alias_id
            INNER JOIN classification_trees ON classification_trees.deleted_at IS NULL
              AND classification_trees.classification_alias_id = classification_aliases.id
            INNER JOIN classification_tree_labels ON classification_tree_labels.deleted_at IS NULL
              AND classification_tree_labels.id = classification_trees.classification_tree_label_id
          WHERE
            classifications.deleted_at IS NULL
            AND classification_tree_labels.name ILIKE 'OutdoorActive - %');
    SQL
  end

  def down
  end
end
