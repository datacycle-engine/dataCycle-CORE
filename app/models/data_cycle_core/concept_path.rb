# frozen_string_literal: true

module DataCycleCore
  class ConceptPath < ApplicationRecord
    belongs_to :concept, foreign_key: :id, inverse_of: false

    has_many :ancestor_concepts, ->(p) { unscope(:where).where('id = ANY(ARRAY[?]::UUID[])', p.ancestor_ids).by_ordered_values(p.ancestor_ids) }, class_name: 'DataCycleCore::Concept', inverse_of: false

    def readonly?
      true
    end
  end
end
