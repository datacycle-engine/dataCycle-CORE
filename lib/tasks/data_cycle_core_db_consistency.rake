# frozen_string_literal: true

require 'rake_helpers/db_helper'

namespace :data_cycle_core do
  namespace :db do
    desc 'perform consistency checks on the db'
    task consistency: :environment do
      # check classification_contents
      DbHelper.status_relation(
        DataCycleCore::ClassificationContent.left_joins(:classification).where('classifications.id IS NULL').count,
        'ClassificationContent',
        'classification_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationContent.left_joins(:content_data).where('things.id IS NULL').count,
        'ClassificationContent',
        'classification_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationContent.where(classification_id: nil).count,
        'ClassificationContent',
        'classification_id IS NULL '
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationContent.where(content_data_id: nil).count,
        'ClassificationContent',
        'content_data_id IS NULL '
      )
      DbHelper.status_relation(
        DataCycleCore::ContentContent.where(content_a_id: nil).count,
        'ContentContent',
        'content_a_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ContentContent.where(content_b_id: nil).count,
        'ContentContent',
        'content_b_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ContentContent.left_joins(:content_a).where('things.id IS NULL').count,
        'ContentContent',
        'content_a_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ContentContent.left_joins(:content_b).where('things.id IS NULL').count,
        'ContentContent',
        'content_b_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationContent.where(content_data_id: nil).count,
        'ClassificationContent',
        'content_data_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::Thing.where('things.external_source_id IS NOT NULL AND things.external_source_id NOT IN (SELECT id FROM external_systems)').count,
        'DataCycleCore::Thing',
        'external_source_id valid'
      )
      DbHelper.status_relation(
        DataCycleCore::ExternalSystemSync.joins("LEFT JOIN things ON things.id = external_system_syncs.syncable_id AND external_system_syncs.syncable_type = 'DataCycleCore::Thing'").where('things.id IS NULL').count,
        'ExternalSystemSync',
        'syncable_id (things)'
      )

      DbHelper.status_relation(
        DataCycleCore::Classification.where('classifications.external_source_id IS NOT NULL AND classifications.external_source_id NOT IN (SELECT id FROM external_systems)').count,
        'Classification',
        'external_source_id valid'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationGroup.where('classification_groups.classification_id NOT IN (SELECT id FROM classifications)').count,
        'ClassificationGroup',
        'classification_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationGroup.where(classification_id: nil).count,
        'ClassificationGroup',
        'classification_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationGroup.where('classification_groups.classification_alias_id NOT IN (SELECT id FROM classification_aliases)').count,
        'ClassificationGroup',
        'classification_alias_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationGroup.where(classification_alias_id: nil).count,
        'ClassificationGroup',
        'classification_alias_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationGroup.where('classification_groups.external_source_id IS NOT NULL AND classification_groups.external_source_id NOT IN (SELECT id FROM external_systems)').count,
        'ClassificationGroup',
        'external_source_id valid'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationAlias.where('classification_aliases.external_source_id IS NOT NULL AND classification_aliases.external_source_id NOT IN (SELECT id FROM external_systems)').count,
        'ClassificationAlias',
        'external_source_id valid'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationTree.where('classification_trees.classification_alias_id NOT IN (SELECT id from classification_aliases)').count,
        'ClassificationTree',
        'classification_alias_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationTree.where(classification_alias_id: nil).count,
        'ClassificationTree',
        'classification_alias_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationTree.where('classification_trees.parent_classification_alias_id IS NOT NULL AND classification_trees.parent_classification_alias_id NOT IN (SELECT id from classification_aliases)').count,
        'ClassificationTree',
        'parent_classification_alias_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationTree.where('classification_trees.classification_tree_label_id NOT IN (SELECT id from classification_tree_labels)').count,
        'ClassificationTree',
        'classification_tree_label_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationTree.where(classification_tree_label_id: nil).count,
        'ClassificationTree',
        'classification_tree_label_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationTree.where('classification_trees.external_source_id IS NOT NULL AND classification_trees.external_source_id NOT IN (SELECT id FROM external_systems)').count,
        'ClassificationTree',
        'external_source_id valid'
      )
      DbHelper.status_relation(
        DataCycleCore::ClassificationTreeLabel.where('classification_tree_labels.external_source_id IS NOT NULL AND classification_tree_labels.external_source_id NOT IN (SELECT id FROM external_systems)').count,
        'ClassificationTreeLabel',
        'external_source_id valid'
      )
    end
  end
end
