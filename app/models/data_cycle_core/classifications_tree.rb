module DataCycleCore
  class ClassificationsTree < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    belongs_to :sub_classifications_alias, class_name: 'ClassificationsAlias', foreign_key: 'classifications_alias_id'
    belongs_to :parent_classifications_alias, class_name: 'ClassificationsAlias', foreign_key: 'parent_classifications_alias_id'

    def parent
      ClassificationsTree.where(
        classifications_alias_id: self.parent_classifications_alias_id,
        external_source_id: self.external_source_id,
        classifications_trees_label_id: self.classifications_trees_label_id
        ).first
    end

    def children
      ClassificationsTree.where(
      parent_classifications_alias_id: self.classifications_alias_id,
      external_source_id: self.external_source_id,
      classifications_trees_label_id: self.classifications_trees_label_id
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
