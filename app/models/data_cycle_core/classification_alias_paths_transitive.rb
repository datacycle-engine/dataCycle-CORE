# frozen_string_literal: true

module DataCycleCore
  class ClassificationAliasPathsTransitive < ApplicationRecord
    self.table_name = 'classification_alias_paths_transitive'

    belongs_to :classfication_alias

    def self.classification_aliases
      return DataCycleCore::ClassificationAlias.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::ClassificationAlias.where(id: all.select(:classification_alias_id))
    end

    def self.mapped_classification_aliases
      raw_sql = <<-SQL.squish
        SELECT capt.classification_alias_id
        FROM (#{all.select('UNNEST(classification_alias_paths_transitive.ancestor_ids) AS classification_alias_id, UNNEST(classification_alias_paths_transitive.link_types) AS link_type').to_sql}) capt
        WHERE capt.link_type = 'related'
      SQL

      DataCycleCore::ClassificationAlias.where("classification_aliases.id IN (#{raw_sql})")
    end
  end
end
