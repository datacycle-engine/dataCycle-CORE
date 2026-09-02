# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      # Validates the +conceptFilter+ param on the facets endpoint. Like +ConceptFilterContract+ but
      # rejects +dct:deleted+, which is a no-op on facets (the count query excludes deleted concepts).
      class FacetConceptFilterContract < BaseContract
        params(FACET_CONCEPT_FILTER, ATTRIBUTE_FILTER)
      end
    end
  end
end
