# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module ContentScore
        class << self
          def by_field_presence(computed_parameters:, computed_definition:, **_args)
            max_value = computed_definition.dig('validations', 'max') || 100
            rating_factor = max_value.to_f / computed_parameters.size
            min_value = computed_definition.dig('validations', 'min') || 0

            computed_definition.dig('compute', 'rating_matrix').each do |max, property_names|
              actual, required = values_present(computed_parameters, property_names)

              max_value = [max_value, max.to_i].min unless actual == required
            end

            return max_value if max_value == min_value

            actual, _required = values_present(computed_parameters, computed_parameters.keys)

            [actual * rating_factor, max_value].min.round
          end

          private

          def values_present(computed_parameters, keys)
            required_count = keys.size
            present_count = 0

            keys.each do |key|
              value = Common.get_values_from_hash(computed_parameters, key.split('.'))

              present_count += 1 if DataCycleCore::DataHashService.present?(value.is_a?(::Hash) ? value.deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) } : value)
            end

            return present_count, required_count
          end
        end
      end
    end
  end
end
