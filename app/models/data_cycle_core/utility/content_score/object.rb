# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Object
        extend Extensions::Tooltip

        class << self
          def by_attribute_and_presence(definition:, parameters:, key:, **_args)
            score = 0
            part = Rational(1, definition.dig('content_score', 'score_matrix').size) unless definition.dig('content_score', 'score_matrix').values.all? { |v| v&.key?('weight') }

            definition.dig('content_score', 'score_matrix').each do |k, v|
              score += (DataCycleCore::DataHashService.present?(parameters&.dig(key, k)) ? 1 : 0) * (part || (v['weight'].is_a?(::Float) ? v['weight'] : v['weight'].to_r))
            end

            score
          end

          def to_tooltip(content, definition, locale)
            case definition.dig('content_score', 'method')
            when 'by_attribute_and_presence'
              tooltip = [tooltip_base_string(definition.dig('content_score', 'method'), locale: locale)]

              if definition.dig('content_score', 'score_matrix').present?
                subtips = ['<ul>']

                definition.dig('content_score', 'score_matrix')
                  &.sort_by { |k, v| [-v&.dig('weight')&.to_r, k] }
                  &.each do |k, v|
                    subtips.push("<li><b>#{definition.dig('properties', k, 'label')}</b> #{"(#{DataCycleCore::LocalizationService.view_helpers.number_with_precision(v['weight'].to_r * 100, precision: 1)}%)" if v.key?('weight')}</li>")
                  end

                tooltip.push("#{subtips.join}</ul>")
              end
            else
              super
            end
          end
        end
      end
    end
  end
end
