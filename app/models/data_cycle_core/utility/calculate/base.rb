# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Calculate
      module Base
        class << self
          def computed_values(properties, data_hash)
            module_name = ('DataCycleCore::' + properties.dig('compute', 'module').classify).safe_constantize
            method_name = module_name.method(properties.dig('compute', 'method'))

            method_arguments = properties.dig('compute', 'parameters').values.map { |value| data_hash.dig(value) }
            computed_value = method_name.call(*method_arguments)
            computed_value
          end
        end
      end
    end
  end
end
