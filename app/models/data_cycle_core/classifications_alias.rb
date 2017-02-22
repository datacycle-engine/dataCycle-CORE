module DataCycleCore
  class ClassificationsAlias < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    has_many :classifications_trees
    has_many :parent_classifications_alias, through: :classifications_trees

    has_many :sub_classifications_trees, class_name: 'ClassificationsTree', foreign_key: 'parent_classifications_alias_id'
    has_many :sub_classifications_alias, through: :sub_classifications_trees

    has_many :classifications_groups
    has_many :classifications, through: :classifications_groups

  end
end
