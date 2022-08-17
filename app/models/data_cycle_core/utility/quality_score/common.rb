# frozen_string_literal: true

module DataCycleCore
  module Utility
    module QualityScore
      module Common
        class << self
          def by_quantity(definition:, data_hash:, key:, **_args)
            Base.score_by_quantity(
              data_hash[key]&.size.to_i,
              definition.dig('quality_score', 'score_matrix')
            )
          end
        end
      end
    end
  end
end
