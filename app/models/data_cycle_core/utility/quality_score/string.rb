# frozen_string_literal: true

module DataCycleCore
  module Utility
    module QualityScore
      module String
        class << self
          def by_length(definition:, data_hash:, key:, **_args)
            Base.score_by_quantity(
              ActionView::Base.full_sanitizer.sanitize(data_hash[key]).presence&.length.to_i,
              definition.dig('quality_score', 'score_matrix')
            )
          end
        end
      end
    end
  end
end
