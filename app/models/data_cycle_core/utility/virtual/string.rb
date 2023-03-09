# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module String
        class << self
          def concat(virtual_parameters:, **args)
            virtual_parameters.map { |item|
              item.is_a?(Hash) ? transform_string(item, args) : item
            }.join
          end

          def transform_string(definition, args)
            case definition.dig('type')
            when 'external_source'
              args.dig(:content)&.external_source&.default_options&.dig(definition.dig('name'))
            when 'I18n'
              definition.dig('type').constantize.send(definition.dig('name'))
            when 'content'
              args.dig(:content).send(definition.dig('name'))
            else
              raise 'Unknown type for string transformation'
            end
          end

          def license_uri(content:, **_args)
            content
              .classifications
              &.classification_aliases
              &.select { |ca| ca.classification_tree_label.name == 'Lizenzen' }
              &.map(&:uri)
              &.compact_blank
              &.first
          end
        end
      end
    end
  end
end
