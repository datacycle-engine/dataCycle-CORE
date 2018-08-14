# frozen_string_literal: true

class ChangeReleaseToClassification < ActiveRecord::Migration[5.1]
  def up
    Rake::Task["#{ENV.fetch('APP_PREFIX', '')}data_cycle_core:update:import_classifications"].invoke
    Rake::Task["#{ENV.fetch('APP_PREFIX', '')}data_cycle_core:update:import_templates"].invoke
    Rake::Task["#{ENV.fetch('APP_PREFIX', '')}data_cycle_core:update:update_all_templates_sql"].invoke(true)

    ['creative_works', 'events', 'persons', 'organizations', 'places'].each do |table_name|
      execute <<-SQL
        INSERT INTO classification_contents (content_data_id, content_data_type, classification_id, relation, created_at, updated_at)
        SELECT DISTINCT ON (#{table_name}.id) #{table_name}.id AS content_data_id, 'DataCycleCore::#{table_name.singularize.classify}' AS content_data_type, (
          SELECT classification_groups.classification_id
          FROM classification_aliases
          INNER JOIN classification_trees
          ON classification_aliases.id = classification_trees.classification_alias_id
          INNER JOIN classification_tree_labels
          ON classification_trees.classification_tree_label_id = classification_tree_labels.id
          INNER JOIN classification_groups
          ON classification_aliases.id = classification_groups.classification_alias_id
          WHERE classification_tree_labels.name = 'Release-Stati'
          AND classification_aliases.name = releases.release_text
          ORDER BY classification_groups.created_at DESC
          LIMIT 1
        ) AS classification_id, 'release_status_id' AS relation, current_timestamp AS created_at, current_timestamp AS updated_at
        FROM #{table_name}
        INNER JOIN #{table_name.singularize}_translations
        ON #{table_name}.id = #{table_name.singularize}_translations.#{table_name.singularize}_id
        INNER JOIN releases
        ON #{table_name.singularize}_translations.release_id = releases.id
        WHERE (#{table_name}.schema -> 'features' ->> 'releasable' = 'true')
        AND #{table_name.singularize}_translations.release_id IS NOT NULL
        ORDER BY #{table_name}.id, #{table_name.singularize}_translations.updated_at DESC;
      SQL

      execute <<-SQL
        INSERT INTO classification_content_histories (content_data_history_id, content_data_history_type, classification_id, relation, created_at, updated_at)
        SELECT DISTINCT ON (#{table_name.singularize}_histories.id) #{table_name.singularize}_histories.id AS content_data_history_id, 'DataCycleCore::#{table_name.singularize.classify}::History' AS content_data_history_type, (
          SELECT classification_groups.classification_id
          FROM classification_aliases
          INNER JOIN classification_trees
          ON classification_aliases.id = classification_trees.classification_alias_id
          INNER JOIN classification_tree_labels
          ON classification_trees.classification_tree_label_id = classification_tree_labels.id
          INNER JOIN classification_groups
          ON classification_aliases.id = classification_groups.classification_alias_id
          WHERE classification_tree_labels.name = 'Release-Stati'
          AND classification_aliases.name = releases.release_text
          ORDER BY classification_groups.created_at DESC
          LIMIT 1
        ) AS classification_id, 'release_status_id' AS relation, current_timestamp AS created_at, current_timestamp AS updated_at
        FROM #{table_name.singularize}_histories
        INNER JOIN #{table_name.singularize}_history_translations
        ON #{table_name.singularize}_histories.id = #{table_name.singularize}_history_translations.#{table_name.singularize}_history_id
        INNER JOIN releases
        ON #{table_name.singularize}_history_translations.release_id = releases.id
        WHERE (#{table_name.singularize}_histories.schema -> 'features' ->> 'releasable' = 'true')
        AND #{table_name.singularize}_history_translations.release_id IS NOT NULL
        ORDER BY #{table_name.singularize}_histories.id, #{table_name.singularize}_history_translations.updated_at DESC;
      SQL

      execute <<-SQL
        UPDATE #{table_name}
        SET metadata = jsonb_insert(#{table_name}.metadata,
                '{release_status_comment}',
                to_jsonb(#{table_name.singularize}_translations.release_comment))
        FROM #{table_name.singularize}_translations
        WHERE #{table_name}.id = #{table_name.singularize}_translations.#{table_name.singularize}_id
        AND #{table_name.singularize}_translations.release_comment IS NOT NULL
        AND (#{table_name}.schema -> 'features' ->> 'releasable' = 'true')
        AND (#{table_name}.metadata ->> 'release_status_comment' IS NULL);
      SQL

      execute <<-SQL
        UPDATE #{table_name.singularize}_histories
        SET metadata = jsonb_insert(#{table_name.singularize}_histories.metadata,
                '{release_status_comment}',
                to_jsonb(#{table_name.singularize}_history_translations.release_comment))
        FROM #{table_name.singularize}_history_translations
        WHERE #{table_name.singularize}_histories.id = #{table_name.singularize}_history_translations.#{table_name.singularize}_history_id
        AND #{table_name.singularize}_history_translations.release_comment IS NOT NULL
        AND (#{table_name.singularize}_histories.schema -> 'features' ->> 'releasable' = 'true')
        AND (#{table_name.singularize}_histories.metadata ->> 'release_status_comment' IS NULL);
      SQL
    end
  end

  def down
    execute <<-SQL
      DELETE FROM classification_contents WHERE relation = 'release_status_id'
    SQL

    execute <<-SQL
      DELETE FROM classification_content_histories WHERE relation = 'release_status_id'
    SQL
  end
end
