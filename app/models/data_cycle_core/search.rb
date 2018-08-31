# frozen_string_literal: true

module DataCycleCore
  class Search < ApplicationRecord
    class ClassificationRelation < ApplicationRecord
      self.table_name = 'classification_contents'

      belongs_to :classification
    end

    belongs_to :content_data, polymorphic: true

    has_many :classification_relations, primary_key: :content_data_id, foreign_key: :content_data_id
    has_many :classifications, through: :classification_relations
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups

    def self.with_classification_aliases(classification_alias_ids)
      classification_alias_ids = Array(classification_alias_ids).map { |id|
        "'#{id}'"
      }.join(',')

      virtual_table_name = "contents_#{SecureRandom.hex}"

      joins(
        <<-SQL.gsub(/\s+/, ' ')
          JOIN (
            WITH RECURSIVE recursive_classification_trees AS (
              SELECT *
              FROM classification_trees
              WHERE classification_trees.parent_classification_alias_id IN (#{classification_alias_ids})
                OR (
                  classification_trees.parent_classification_alias_id IS NULL
                  AND classification_trees.classification_alias_id IN (#{classification_alias_ids})
                )
              UNION ALL
              SELECT classification_trees.*
              FROM classification_trees
              INNER JOIN recursive_classification_trees
                ON classification_trees.parent_classification_alias_id = recursive_classification_trees.classification_alias_id
            )
            SELECT DISTINCT ON (content_data_id, content_data_type) content_data_id, content_data_type
            FROM classification_contents
            JOIN classification_groups
              ON classification_contents.classification_id = classification_groups.classification_id
            JOIN recursive_classification_trees
              ON recursive_classification_trees.classification_alias_id = classification_groups.classification_alias_id
            WHERE classification_groups.deleted_at IS NULL AND recursive_classification_trees.deleted_at IS NULL
          ) AS #{virtual_table_name}
            ON searches.content_data_id = #{virtual_table_name}.content_data_id
            AND searches.content_data_type = #{virtual_table_name}.content_data_type
        SQL
      )
    end
  end
end
