# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByClassificationTreePath < Base
        attr_reader :subject, :conditions, :concept_paths

        def initialize(*concept_paths)
          @concept_paths = Array.wrap(concept_paths).flatten.map(&:to_s)
          @subject = DataCycleCore::Thing

          classification_ids = DataCycleCore::Concept.by_full_paths(@concept_paths).pluck(:id)

          @conditions = { classification_aliases: {id: classification_ids}}
        end

        private

        def to_restrictions(**)
          to_restriction(concept_paths: concept_paths.join(', '))
        end
      end
    end
  end
end
