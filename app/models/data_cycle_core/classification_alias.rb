module DataCycleCore
  class ClassificationAlias < ApplicationRecord
    belongs_to :external_source

    acts_as_paranoid

    has_one :classification_tree, dependent: :destroy
    has_one :parent_classification_alias, through: :classification_tree

    has_one :classification_tree_label, through: :classification_tree_with_deleted

    has_one :classification_tree_with_deleted, -> { with_deleted }, class_name: 'ClassificationTree', foreign_key: 'classification_alias_id'
    has_one :parent_classification_alias_with_deleted, through: :classification_tree_with_deleted, source: :parent_classification_alias

    has_many :sub_classification_trees, class_name: 'ClassificationTree', foreign_key: 'parent_classification_alias_id', dependent: :destroy
    has_many :sub_classification_alias, through: :sub_classification_trees

    has_many :classification_groups, dependent: :destroy
    has_many :classifications, -> { order(:name) }, through: :classification_groups

    def self.for_tree(tree_name)
      joins(classification_tree: :classification_tree_label)
        .where('classification_trees' => { 'classification_tree_labels' => { 'name' => tree_name } })
    end

    def self.with_name(*names)
      where(name: names.flatten)
    end

    def self.with_descendants
      query = self.is_a?(ActiveRecord::Relation) ? self : all

      sql = <<-SQL.gsub(/\s+/, ' ').gsub(/(?<=\A)\s+/, '').gsub(/\s+(?=\z)/, '')
        WITH RECURSIVE aliases AS (
          #{query.to_sql}
          UNION
          SELECT classification_aliases.*
          FROM classification_aliases
          JOIN classification_trees ON classification_trees.classification_alias_id = classification_aliases.id
          JOIN aliases AS parent_aliases ON parent_aliases.id = classification_trees.parent_classification_alias_id
        ) SELECT id FROM aliases
        SQL

      query.unscope(where: query.bound_attributes.map(&:name)).where('classification_aliases.id IN (' + sql + ')')
    end

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 10.minutes) do
        if parent_classification_alias_with_deleted
          [parent_classification_alias_with_deleted] + parent_classification_alias_with_deleted.ancestors
        else
          [classification_tree_with_deleted.classification_tree_label_with_deleted]
        end
      end
    end

    def descendants
      Rails.cache.fetch("#{cache_key}/descendants", expires_in: 10.minutes) do
        if sub_classification_alias
          classifications.to_a + sub_classification_alias.includes(:classifications).order(:name).map(&:descendants).to_a
        else
          classifications.to_a
        end
      end
    end
  end
end
