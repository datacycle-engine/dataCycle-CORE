# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module String
        extend Extensions::Tooltip
        extend Extensions::TooltipScoreMatrix

        class << self
          def by_length(definition:, data_hash:, key:, **_args)
            Base.score_by_quantity(
              ActionView::Base.full_sanitizer.sanitize(data_hash[key]).presence&.length.to_i,
              definition.dig('content_score', 'score_matrix')
            )
          end
        end
      end
    end
  end
end
