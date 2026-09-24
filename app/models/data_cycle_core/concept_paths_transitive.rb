# frozen_string_literal: true

module DataCycleCore
  class ConceptPathsTransitive < ApplicationRecord
    self.table_name = 'concept_paths_transitive'

    belongs_to :concept

    def self.concepts
      DataCycleCore::Concept.where(id: pluck(:concept_id))
    end

    def self.mapped_concepts
      raw_sql = <<~SQL.squish
        SELECT cpt.concept_id
        FROM (#{select('UNNEST(concept_paths_transitive.ancestor_ids) AS concept_id, UNNEST(concept_paths_transitive.link_types) AS link_type').to_sql}) cpt
        WHERE cpt.link_type = 'related'
      SQL

      DataCycleCore::Concept.where("concepts.id IN (#{raw_sql})")
    end
  end
end
