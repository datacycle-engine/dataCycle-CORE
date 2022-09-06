# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Content
        class << self
          def minimum(content:, parameters:, **_args)
            scores = calculate_scores(content: content, parameters: parameters).values

            scores.flatten!
            scores.compact!

            scores.min
          end

          def by_field_presence(parameters:, definition:, **_args)
            max_value = 1.0
            rating_factor = max_value / parameters.size
            min_value = 0

            definition.dig('content_score', 'score_matrix').each do |max, property_names|
              actual, required = values_present(parameters, property_names)

              max_value = [max_value, max.to_f].min unless actual == required
            end

            return max_value if max_value == min_value

            actual, _required = values_present(parameters, parameters.keys)

            [actual * rating_factor, max_value].min
          end

          private

          def values_present(parameters, keys)
            required_count = keys.size
            present_count = 0

            keys.each do |key|
              value = DataCycleCore::Utility::Compute::Common.get_values_from_hash(parameters, key.split('.'))

              present_count += 1 if DataCycleCore::DataHashService.present?(value.is_a?(::Hash) ? value.deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) } : value)
            end

            return present_count, required_count
          end

          def calculate_scores(content:, parameters:)
            scores = {}

            parameters.each do |key, value|
              scores[key] = content.calculate_content_score(key, { key => value })
            end

            scores
          end
        end
      end
    end
  end
end
