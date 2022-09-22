# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Content
        class << self
          def by_minimum(content:, parameters:, **_args)
            scores = Base.calculate_scores_by_method_or_presence(content: content, parameters: parameters).values

            scores.flatten!
            scores.compact!

            scores.min
          end

          def by_weight_matrix(content:, parameters:, definition:, **_args)
            scores = Base.calculate_scores_by_method_or_presence(content: content, parameters: parameters)

            definition.dig('content_score', 'weight_matrix')&.sum { |k, v| scores[k].to_f * v.to_r }
          end

          def by_field_presence(parameters:, definition:, **_args)
            max_value = 1.0
            rating_factor = max_value / parameters.size
            min_value = 0

            definition.dig('content_score', 'score_matrix').each do |max, property_names|
              actual, required = Base.values_present(parameters, property_names)

              max_value = [max_value, max.to_f].min unless actual == required
            end

            return max_value if max_value == min_value

            actual, _required = Base.values_present(parameters, parameters.keys)

            [actual * rating_factor, max_value].min
          end
        end
      end
    end
  end
end
