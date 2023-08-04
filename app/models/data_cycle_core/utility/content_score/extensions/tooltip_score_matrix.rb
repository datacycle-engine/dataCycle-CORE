# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Extensions
        module TooltipScoreMatrix
          def to_tooltip(_content, definition, locale)
            return super if definition.dig('content_score', 'score_matrix').blank?

            tooltip = [tooltip_base_string(definition.dig('content_score', 'method'), locale:)]

            subtips = ['<ul>']
            definition.dig('content_score', 'score_matrix')&.each do |k, v|
              subtips.push("<li>#{tooltip_string("score_matrix.#{k}", locale:, value: v)}</li>")
            end
            tooltip.push("#{subtips.join}</ul>")

            tooltip.compact.join
          end
        end
      end
    end
  end
end
