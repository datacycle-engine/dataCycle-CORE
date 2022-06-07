# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Classification
        class << self
          def concat(virtual_parameters:, content:, virtual_definition:, **_args)
            values = []

            virtual_parameters.each do |param|
              values << classifcation_alias_value(content.send(param), virtual_definition.dig(:virtual, :key))
            end

            values.join(', ')
          end

          def classifcation_alias_value(classifications, key)
            classifications
              &.classification_aliases
              &.map { |ca| ca.send(key) || ca.internal_name }
          end
        end
      end
    end
  end
end
