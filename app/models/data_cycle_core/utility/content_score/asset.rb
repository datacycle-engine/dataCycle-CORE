# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Asset
        extend Extensions::Tooltip

        class << self
          def by_mime_types(definition:, parameters:, key:, **_args)
            Array.wrap(definition.dig('content_score', 'mime_types')).include?(parameters[key]) ? 1 : 0
          end

          def to_tooltip(content, definition, locale)
            return super if definition.dig('content_score', 'method') != 'by_mime_types'

            tooltip = [tooltip_base_string(definition.dig('content_score', 'method'), locale: locale)]

            if definition.dig('content_score', 'mime_types').present?
              tooltip.push(tooltip_string('mime_types', locale: locale))

              subtips = ['<ul>']
              definition.dig('content_score', 'mime_types').each do |v|
                subtips.push("<li><b>#{v}</b></li>")
              end

              tooltip.push("#{subtips.join}</ul>")
            end

            tooltip.compact.join('<br>')
          end
        end
      end
    end
  end
end
