module DataCycleCore
  class ClassificationAlias < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    has_many :classification_trees, dependent: :destroy
    has_many :parent_classification_alias, through: :classification_trees

    has_many :sub_classification_trees, class_name: 'ClassificationTree', foreign_key: 'parent_classification_alias_id', dependent: :destroy
    has_many :sub_classification_alias, through: :sub_classification_trees

    has_many :classification_groups, dependent: :destroy
    has_many :classifications, through: :classification_groups

  end
end
