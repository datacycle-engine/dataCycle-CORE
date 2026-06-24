# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class BildPhash < Base
        PARAMETERS = ['asset'].freeze

        class << self
          def duplicates(content:, **)
            content.asset&.duplicate_candidates_with_score
          end
        end
      end
    end
  end
end
