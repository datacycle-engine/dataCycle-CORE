# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Number
        extend Extensions::Tooltip
        extend Extensions::TooltipScoreMatrix

        class << self
          def by_quantity(definition:, data_hash:, key:, **_args)
            Base.score_by_quantity(
              data_hash[key].to_i,
              definition.dig('content_score', 'score_matrix')
            )
          end

          def by_presence(key:, parameters:, **_args)
            parameters[key].to_i.positive? ? 1 : 0
          end
        end
      end
    end
  end
end
