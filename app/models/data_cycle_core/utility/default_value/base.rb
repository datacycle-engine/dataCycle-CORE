# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Base
        class << self
          def default_values(key, properties, data_hash, content)
            return if properties['default_value'].is_a?(String) && properties['type'] == 'classification'
            return properties['default_value'] if properties['default_value'].is_a?(String)

            module_name = properties.dig('default_value', 'module').classify.safe_constantize
            method_name = module_name.method(properties.dig('default_value', 'method'))

            property_parameters = properties.dig('default_value', 'parameters').values.map { |value| data_hash.dig(value) }

            method_name.try(:call, { property_parameters: property_parameters, key: key, data_hash: data_hash, content: content, property_definition: properties })
          end
        end
      end
    end
  end
end
