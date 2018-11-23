# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :db do
    desc 'perform consistency checks on the db'
    task consistency: :environment do
      # check classification_contents
      status_relation(
        DataCycleCore::ClassificationContent.where('classification_contents.classification_id NOT IN (SELECT id FROM classifications)').count,
        'ClassificationContent',
        'classification_id'
      )
      status_relation(
        DataCycleCore::ClassificationContent.where(classification_id: nil).count,
        'ClassificationContent',
        'classification_id IS NULL '
      )
      status_relation(
        DataCycleCore::ClassificationContent.where('classification_contents.external_source_id IS NOT NULL AND classification_contents.external_source_id NOT IN (SELECT id FROM external_sources)').count,
        'ClassificationContent',
        'external_source_id valid'
      )
      status_relation(
        DataCycleCore::ClassificationContent.where(content_data_type: nil).count,
        'ClassificationContent',
        'content_data_type IS NULL'
      )
      status_relation(
        DataCycleCore::ClassificationContent.where(content_data_id: nil).count,
        'ClassificationContent',
        'content_data_id IS NULL'
      )
      status_relation(
        DataCycleCore::ClassificationContent.where(content_data_type: 'DataCycleCore::Thing').where('classification_contents.content_data_id NOT IN (SELECT id FROM things)').count,
        'ClassificationContent',
        'content_data_id(DataCycleCore::Thing)'
      )
      status_relation(
        DataCycleCore::Thing.where('things.external_source_id IS NOT NULL AND things.external_source_id NOT IN (SELECT id FROM external_sources)').count,
        DataCycleCore::Thing,
        'external_source_id valid'
      )
      status_relation(
        DataCycleCore::Classification.where('classifications.external_source_id IS NOT NULL AND classifications.external_source_id NOT IN (SELECT id FROM external_sources)').count,
        'Classification',
        'external_source_id valid'
      )
      status_relation(
        DataCycleCore::ClassificationGroup.where('classification_groups.classification_id NOT IN (SELECT id FROM classifications)').count,
        'ClassificationGroup',
        'classification_id'
      )
      status_relation(
        DataCycleCore::ClassificationGroup.where(classification_id: nil).count,
        'ClassificationGroup',
        'classification_id IS NULL'
      )
      status_relation(
        DataCycleCore::ClassificationGroup.where('classification_groups.classification_alias_id NOT IN (SELECT id FROM classification_aliases)').count,
        'ClassificationGroup',
        'classification_alias_id'
      )
      status_relation(
        DataCycleCore::ClassificationGroup.where(classification_alias_id: nil).count,
        'ClassificationGroup',
        'classification_alias_id IS NULL'
      )
      status_relation(
        DataCycleCore::ClassificationGroup.where('classification_groups.external_source_id IS NOT NULL AND classification_groups.external_source_id NOT IN (SELECT id FROM external_sources)').count,
        'ClassificationGroup',
        'external_source_id valid'
      )
      status_relation(
        DataCycleCore::ClassificationAlias.where('classification_aliases.external_source_id IS NOT NULL AND classification_aliases.external_source_id NOT IN (SELECT id FROM external_sources)').count,
        'ClassificationAlias',
        'external_source_id valid'
      )
      status_relation(
        DataCycleCore::ClassificationTree.where('classification_trees.classification_alias_id NOT IN (SELECT id from classification_aliases)').count,
        'ClassificationTree',
        'classification_alias_id'
      )
      status_relation(
        DataCycleCore::ClassificationTree.where(classification_alias_id: nil).count,
        'ClassificationTree',
        'classification_alias_id IS NULL'
      )
      status_relation(
        DataCycleCore::ClassificationTree.where('classification_trees.parent_classification_alias_id IS NOT NULL AND classification_trees.parent_classification_alias_id NOT IN (SELECT id from classification_aliases)').count,
        'ClassificationTree',
        'parent_classification_alias_id'
      )
      status_relation(
        DataCycleCore::ClassificationTree.where('classification_trees.classification_tree_label_id NOT IN (SELECT id from classification_tree_labels)').count,
        'ClassificationTree',
        'classification_tree_label_id'
      )
      status_relation(
        DataCycleCore::ClassificationTree.where(classification_tree_label_id: nil).count,
        'ClassificationTree',
        'classification_tree_label_id IS NULL'
      )
      status_relation(
        DataCycleCore::ClassificationTree.where('classification_trees.external_source_id IS NOT NULL AND classification_trees.external_source_id NOT IN (SELECT id FROM external_sources)').count,
        'ClassificationTree',
        'external_source_id valid'
      )
      status_relation(
        DataCycleCore::ClassificationTreeLabel.where('classification_tree_labels.external_source_id IS NOT NULL AND classification_tree_labels.external_source_id NOT IN (SELECT id FROM external_sources)').count,
        'ClassificationTreeLabel',
        'external_source_id valid'
      )
    end

    private

    def status_relation(data, data_class, linked_class)
      if data.positive?
        puts "[ERROR] Inconsitency for #{linked_class} in #{data_class} (#{data})"
      else
        puts "[OK]    checked references, #{data_class} -> #{linked_class}"
      end
    end
  end
end
