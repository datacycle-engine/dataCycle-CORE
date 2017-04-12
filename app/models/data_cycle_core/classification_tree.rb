module DataCycleCore
  class ClassificationTree < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    belongs_to :sub_classification_alias, class_name: 'ClassificationAlias', foreign_key: 'classification_alias_id'
    belongs_to :parent_classification_alias, class_name: 'ClassificationAlias', foreign_key: 'parent_classification_alias_id'

    def parent
      ClassificationTree.where(
        classification_alias_id: self.parent_classification_alias_id,
        external_source_id: self.external_source_id,
        classification_tree_label_id: self.classification_tree_label_id
        ).first
    end

    def children
      ClassificationTree.where(
      parent_classification_alias_id: self.classification_alias_id,
      external_source_id: self.external_source_id,
      classification_tree_label_id: self.classification_tree_label_id
      )
    end

    def ancestors
      node = self
      nodes = []
      nodes << node = node.parent while node.parent
      nodes
    end
  end
end
