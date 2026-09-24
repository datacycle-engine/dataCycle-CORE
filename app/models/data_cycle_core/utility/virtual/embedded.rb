# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Embedded
        class << self
          # The children are whatever content_contents links to the parent, not what the template
          # declares, so a child that does not carry the configured key drops out of the list
          # instead of raising NoMethodError for the whole content.
          def map(virtual_parameters:, virtual_definition:, language:, content:, **_args)
            key = virtual_definition.dig('virtual', 'key')
            values = []

            virtual_parameters.each do |param|
              data = content.load_embedded_objects(param, nil, true, language).includes(:translations, :concepts)

              next if data.blank?

              data.each do |embedded|
                value = I18n.with_locale(embedded.first_available_locale) { embedded.try(key) }

                values << value unless value.nil?
              end
            end

            values
          end
        end
      end
    end
  end
end
