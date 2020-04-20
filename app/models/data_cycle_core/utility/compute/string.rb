# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module String
        class << self
          def concat(**args)
            args.dig(:computed_definition)&.dig('compute', 'parameters')&.values&.map { |item|
              item.is_a?(Hash) ? transform_string(item, args) : item
            }&.join
          end

          def transform_string(definition, args)
            case definition.dig('type')
            when 'external_source'
              args.dig(:content)&.external_source&.default_options&.dig(definition.dig('name'))
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

          def attribution_name(**args)
            attribution_name = []

            args.dig(:computed_definition, 'compute', 'parameters')&.sort&.each do |definition|
              case args[:content]&.properties_for(definition[1])&.dig('type')
              when 'linked'
                attribution_name.push((args[:data_hash]&.key?(definition[1]) ? DataCycleCore::Thing.where(id: args.dig(:computed_parameters, definition[0]&.to_i)) : args[:content].try(definition[1])).map { |c| I18n.with_locale(c.first_available_locale) { c.title.presence } }.compact.join(', ').presence)
              else
                attribution_name.push(args[:data_hash]&.key?(definition[1]) ? args.dig(:computed_parameters, definition[0]&.to_i).presence : args[:content].try(definition[1]).presence)
              end
            end

            attribution_name.compact.blank? ? nil : attribution_name.compact.join(' / ').prepend('(c) ')
          end
        end
      end
    end
  end
end
