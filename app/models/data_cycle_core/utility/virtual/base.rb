# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Base
        class << self
          def virtual_values(key, properties, content, language = nil)
            module_name = ('DataCycleCore::' + properties.dig('virtual', 'module').classify).safe_constantize
            method_name = module_name.method(properties.dig('virtual', 'method'))
            virtual_parameters = properties.dig('virtual', 'parameters')&.values
            language ||= content.first_available_locale

            virtual_value = method_name.try(:call, **{ virtual_parameters: virtual_parameters, key: key, content: content, virtual_definition: properties, language: language })
            virtual_value
          end
        end
      end
    end
  end
end
