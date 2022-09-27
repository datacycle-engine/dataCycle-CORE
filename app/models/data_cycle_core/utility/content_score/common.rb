# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Common
        class << self
          def by_quantity(definition:, data_hash:, key:, **_args)
            Base.score_by_quantity(
              data_hash[key]&.size.to_i,
              definition.dig('content_score', 'score_matrix')
            )
          end

          def by_presence(key:, parameters:, **_args)
            Base.value_present?(parameters, key) ? 1 : 0
          end
        end
      end
    end
  end
end
