# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Classification
        class << self
          def by_name(property_definition:, **_additional_args)
            if property_definition&.dig('default_value').is_a?(Hash)
              value = property_definition&.dig('default_value', 'value')
            else
              value = property_definition&.dig('default_value')
            end

            Array.wrap(DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(property_definition&.dig('tree_label'), value))
          end
        end
      end
    end
  end
end
