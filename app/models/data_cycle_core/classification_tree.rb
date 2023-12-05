# frozen_string_literal: true

module DataCycleCore
  class ClassificationTree < ApplicationRecord
    acts_as_paranoid

    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'
    belongs_to :classification_tree_label
    belongs_to :classification_tree_label_with_deleted, -> { with_deleted }, class_name: 'ClassificationTreeLabel', foreign_key: 'classification_tree_label_id'

    belongs_to :sub_classification_alias, class_name: 'ClassificationAlias', foreign_key: 'classification_alias_id', dependent: :destroy
    belongs_to :parent_classification_alias, class_name: 'ClassificationAlias'

    validate :child_distinct_from_parent

    def parent
      ClassificationTree.find_by(
        classification_alias_id: parent_classification_alias_id,
        external_source_id:,
        classification_tree_label_id:
      )
    end

    def children
      ClassificationTree.where(
        parent_classification_alias_id: classification_alias_id,
        external_source_id:,
        classification_tree_label_id:
      )
    end

    def ancestors
      node = self
      nodes = []
      nodes << node = node.parent while node.parent
      nodes
    end

    private

    def child_distinct_from_parent
      errors.add(:classification_alias_id, "can't be same as parent_classification_alias_id") if parent_classification_alias_id.present? && classification_alias_id.present? && parent_classification_alias_id == classification_alias_id
    end
  end
end
