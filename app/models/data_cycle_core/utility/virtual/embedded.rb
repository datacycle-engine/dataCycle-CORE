# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Embedded
        class << self
          def map(**args)
            language = args.dig(:language)
            virtual_parameters = args.dig(:virtual_parameters)
            content = args.dig(:content)
            definition = args.dig(:virtual_definition)
            values = []
            virtual_parameters.each do |param|
              data = content.load_embedded_objects(param, nil, true, language).includes(:translations, :classifications)
              next if data.blank?
              data.each do |embedded|
                values << I18n.with_locale(embedded.first_available_locale) { embedded.send(definition.dig('virtual', 'key')) }
              end
            end
            values
          end
        end
      end
    end
  end
end
