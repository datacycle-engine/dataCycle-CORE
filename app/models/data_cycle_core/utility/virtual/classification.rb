# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Classification
        class << self
          def concat(**args)
            virtual_parameters = args.dig(:virtual_parameters)
            content = args.dig(:content)
            definition = args.dig(:virtual_definition)&.deep_symbolize_keys
            values = []
            virtual_parameters.each do |param|
              values << classifcation_alias_value(content.send(param), definition.dig(:virtual, :key))
            end
            values.join(', ')
          end

          def classifcation_alias_value(classifications, key)
            classifications
              &.map(&:classification_aliases)
              &.flatten
              &.uniq
              &.map { |classification_alias| classification_alias.send(key) || classification_alias.internal_name }
          end
        end
      end
    end
  end
end
