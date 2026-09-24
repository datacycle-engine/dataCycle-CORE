# frozen_string_literal: true

module DataCycleCore
  class ConceptContent < ApplicationRecord
    belongs_to :content_data, class_name: 'DataCycleCore::Thing'
    belongs_to :concept

    class History < ApplicationRecord
      belongs_to :content_data_history, class_name: 'DataCycleCore::Thing::History'
      belongs_to :concept
    end

    class << self
      def with_content(content_data_id)
        where(content_data_id:)
      end

      def with_relation(relation_name)
        where(relation: relation_name)
      end

      def with_concept_ids(ids)
        where(concept_id: ids)
      end

      def concepts
        DataCycleCore::Concept.where(id: pluck(:concept_id))
      end
    end
  end
end
