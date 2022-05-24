# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Base
        class << self
          def virtual_values(key, content, language = nil)
            properties = content.properties_for(key)&.with_indifferent_access

            module_name = ('DataCycleCore::' + properties.dig('virtual', 'module').classify).safe_constantize
            method_name = module_name.method(properties.dig('virtual', 'method'))
            virtual_parameters = Array.wrap(properties&.dig('virtual', 'parameters'))
            language ||= content.first_available_locale

            method_name.try(:call, **{
              virtual_parameters: virtual_parameters,
              key: key,
              content: content,
              virtual_definition: properties,
              language: language
            })
          end
        end
      end
    end
  end
end
