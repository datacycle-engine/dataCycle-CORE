# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Virtual
        class << self
          def by_presence(content:, key:, **_args)
            return 0 unless content&.virtual_property_names&.include?(key)

            DataCycleCore::DataHashService.deep_present?(content.try(key)) ? 1 : 0
          end

          def by_quantity(content:, key:, definition:, **_args)
            return 0 unless content&.virtual_property_names&.include?(key)

            Base.score_by_quantity(
              content.try(key)&.size.to_i,
              definition.dig('content_score', 'score_matrix')
            )
          end
        end
      end
    end
  end
end
