module DataCycleCore
  class ClassificationAlias < ApplicationRecord

    include DataSetter

    belongs_to :external_source

    has_one :classification_tree, dependent: :destroy
    has_one :parent_classification_alias, through: :classification_tree

    has_many :sub_classification_trees, class_name: 'ClassificationTree', foreign_key: 'parent_classification_alias_id', dependent: :destroy
    has_many :sub_classification_alias, through: :sub_classification_trees

    has_many :classification_groups, dependent: :destroy
    has_many :classifications, through: :classification_groups

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 10.minutes) do
        if parent_classification_alias
          [parent_classification_alias] + parent_classification_alias.ancestors
        else
          [classification_tree.classification_tree_label]
        end
      end
    end
  end
end
