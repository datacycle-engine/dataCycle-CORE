# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Base
        class << self
          def computed_values(key, properties, data_hash, content)
            module_name = ('DataCycleCore::' + properties.dig('compute', 'module').classify).safe_constantize
            method_name = module_name.method(properties.dig('compute', 'method'))
            computed_parameters = properties.dig('compute', 'parameters').values.map { |value| value.is_a?(::String) ? data_hash.dig(value) : value }

            return unless validate_computed(data_hash: data_hash, content: content, computed_definition: properties)
            computed_value = method_name.try(:call, **{ computed_parameters: computed_parameters, key: key, data_hash: data_hash, content: content, computed_definition: properties })
            computed_value
          end

          def validate_computed(data_hash:, content:, computed_definition:)
            return true if computed_definition.dig('compute', 'depends').blank?
            computed_definition.dig('compute', 'depends').each do |_v_key, v_value|
              return false unless validate(definition: v_value, data_hash: data_hash, content: content)
            end
            true
          end

          def validate(definition:, data_hash:, content:)
            expected_value = definition.dig('value')
            value = case definition.dig('type')
                    when 'external_source'
                      content&.external_source&.default_options&.dig(definition.dig('name'))
                    when 'I18n'
                      definition.dig('type').constantize.send(definition.dig('name'))
                    when 'content'
                      content.send(definition.dig('name'))
                    when 'data_hash'
                      data_hash.dig(definition.dig('name'))
                    else
                      raise 'Unknown type for validation'
                    end

            send(definition.dig('method'), value, expected_value)
          end

          def equals?(value_a, value_b)
            value_a == value_b
          end

          def exists?(value_a, _value_b)
            value_a.present?
          end
        end
      end
    end
  end
end
