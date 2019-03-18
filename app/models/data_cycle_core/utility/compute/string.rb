# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module String
        class << self
          def concat(**args)
            args.dig(:computed_definition)&.dig('compute', 'parameters')&.values&.map do |item|
              item.is_a?(Hash) ? transform_string(item, args) : item
            end&.join
          end

          def transform_string(definition, args)
            case definition.dig('type')
            when 'I18n'
              definition.dig('type').constantize.send(definition.dig('name'))
            when 'content'
              args.dig(:content).send(definition.dig('name'))
            when 'data_hash'
              args.dig(:data_hash).dig(definition.dig('name'))
            else
              raise 'Unknown type for string transformation'
            end
          end
        end
      end
    end
  end
end
