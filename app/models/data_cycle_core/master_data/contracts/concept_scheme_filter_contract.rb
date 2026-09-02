# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      # Validates the +filter+ param on the concept-scheme (classification-tree-label) listing.
      # Like +ConceptFilterContract+ but without the concept-hierarchy filters (skos:*).
      class ConceptSchemeFilterContract < BaseContract
        params(CONCEPT_SCHEME_FILTER, ATTRIBUTE_FILTER)
      end
    end
  end
end
