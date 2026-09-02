# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      # Validates the +conceptFilter+ (and, on the concept endpoints, +filter+) params that constrain
      # which concepts are returned. Counterpart to +ApiFilterContract+, which validates content filters.
      class ConceptFilterContract < BaseContract
        params(CONCEPT_FILTER, ATTRIBUTE_FILTER)
      end
    end
  end
end
