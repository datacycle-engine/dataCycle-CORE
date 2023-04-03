# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Base
        class << self
          def virtual_values(key, content, language = nil)
            properties = content.properties_for(key)&.with_indifferent_access

            method_name = DataCycleCore::ModuleService
              .load_module(properties.dig('virtual', 'module').classify, 'Utility::Virtual')
              .method(properties.dig('virtual', 'method'))
            virtual_parameters = Array.wrap(properties&.dig('virtual', 'parameters'))
            language ||= content.first_available_locale

            method_name.call(
              virtual_parameters: virtual_parameters,
              key: key,
              content: content,
              virtual_definition: properties,
              language: language
            )
          end
        end
      end
    end
  end
end
