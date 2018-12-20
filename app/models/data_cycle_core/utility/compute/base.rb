# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Base
        class << self
          def computed_values(key, properties, data_hash, content)
            module_name = ('DataCycleCore::' + properties.dig('compute', 'module').classify).safe_constantize
            method_name = module_name.method(properties.dig('compute', 'method'))

            computed_parameters = properties.dig('compute', 'parameters').values.map { |value| data_hash.dig(value) }
            computed_value = method_name.try(:call, { computed_parameters: computed_parameters, key: key, data_hash: data_hash, content: content })
            computed_value
          end
        end
      end
    end
  end
end
