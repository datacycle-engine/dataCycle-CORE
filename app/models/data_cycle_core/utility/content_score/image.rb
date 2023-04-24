# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Image
        extend Extensions::Tooltip

        class << self
          def by_aspect_ratio(definition:, parameters:, **_args)
            aspect_ratio = definition.dig('content_score', 'aspect_ratio')

            return 0 if aspect_ratio.present? && (parameters['width'].to_r.zero? || parameters['height'].to_r.zero? || Base.score_by_quantity(parameters['width'].to_r / parameters['height'].to_r, aspect_ratio).zero?)

            score = 1

            definition.dig('content_score', 'score_matrix')&.each do |k, v|
              score *= Base.score_by_quantity(parameters[k], v)
            end

            score
          end

          def to_tooltip(content, definition, locale)
            return super if definition.dig('content_score', 'method') != 'by_aspect_ratio'

            tooltip = [tooltip_base_string(definition.dig('content_score', 'method'), locale: locale)]

            if definition.dig('content_score', 'aspect_ratio').present?
              subtips = ['<ul>']
              definition.dig('content_score', 'aspect_ratio')&.each do |k, v|
                subtips.push("<li>#{tooltip_string("score_matrix.#{k}", locale: locale, value: v)}</li>")
              end
              tooltip.push("#{subtips.join}</ul>")
            end

            if definition.dig('content_score', 'score_matrix').present?
              tooltip.push(tooltip_string('further_restricions', locale: locale))

              subtips = ['<ul>']
              definition.dig('content_score', 'score_matrix')
                .sort_by { |k, _v| content.properties_for(k)&.[]('sorting') }
                .each do |k, c|
                sub_text = []
                sub_text.push('<ul>')
                c.each { |m, v| sub_text.push("<li>#{tooltip_string("score_matrix.#{m}", locale: locale, value: v)}</li>") }
                sub_text.push('</ul>')

                subtips.push("<li><b>#{content.class.human_attribute_name(k, { base: content, definition: content.properties_for(k), locale: locale })}</b> #{sub_text.join}</li>")
              end

              tooltip.push("#{subtips.join}</ul>")
            end

            tooltip.compact.join
          end
        end
      end
    end
  end
end
