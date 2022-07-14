# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module ContentScore
        class << self
          def by_field_presence(content:, computed_parameters:, computed_definition:, **_args)
            max_value = computed_definition.dig('validations', 'max') || 100
            rating_factor = max_value.to_f / computed_parameters.size
            min_value = computed_definition.dig('validations', 'min') || 0

            computed_definition.dig('compute', 'rating_matrix').each do |max, property_names|
              actual, required = values_present(content, computed_parameters, property_names)

              max_value = [max_value, max.to_i].min unless actual == required
            end

            return max_value if max_value == min_value

            actual, _required = values_present(content, computed_parameters, computed_parameters.keys)

            [actual * rating_factor, max_value].min.round
          end

          private

          def values_present(content, computed_parameters, keys)
            required_count = keys.size
            present_count = 0

            keys.each do |key|
              value = get_values_from_hash(content, computed_parameters, key.split('.'))

              present_count += 1 if DataCycleCore::DataHashService.present?(value.is_a?(::Hash) ? value.deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) } : value)
            end

            return present_count, required_count
          end

          def get_values_from_hash(content, data_hash, key_path)
            return data_hash if key_path.blank?

            if data_hash.is_a?(::Hash)
              key = key_path.first

              if data_hash.key?(key) || data_hash.dig('datahash')&.key?(key) || data_hash.dig('translations', I18n.locale.to_s)&.key?(key)
                value = data_hash.dig(key) || data_hash.dig('datahash', key) || data_hash.dig('translations', I18n.locale.to_s, key)
              else
                id = data_hash.dig('id') || data_hash.dig('datahash', 'id') || data_hash.dig('translations', I18n.locale.to_s, 'id')
                value = DataCycleCore::Thing.find_by(id: id)&.property_value_for_set_datahash(key)
              end

              get_values_from_hash(content, value, key_path.drop(1))
            elsif data_hash.is_a?(::Array) && data_hash.first.to_s.uuid?
              DataCycleCore::Thing.where(id: data_hash).map { |v| get_values_from_hash(content, { key_path.first => v.property_value_for_set_datahash(key_path.first) }, key_path) }
            elsif data_hash.is_a?(::Array)
              data_hash.map { |v| get_values_from_hash(content, v, key_path) }
            end
          end
        end
      end
    end
  end
end
