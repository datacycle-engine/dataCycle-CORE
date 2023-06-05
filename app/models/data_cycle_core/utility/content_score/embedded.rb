# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Embedded
        extend Extensions::Tooltip

        class << self
          def minimum(definition:, parameters:, key:, **_args)
            scores = calculate_nested_scores(definition: definition, objects: parameters[key])

            scores.min
          end

          def by_name_and_length(definition:, parameters:, key:, **_args)
            score = 0
            part = Rational(1, definition.dig('content_score', 'score_matrix').size) unless definition.dig('content_score', 'score_matrix').values.all? { |v| v&.key?('weight') }

            definition.dig('content_score', 'score_matrix').each do |k, v|
              score += Base.score_by_quantity(
                ActionView::Base.full_sanitizer.sanitize(parameters[key]&.find { |e| e['name'] == k }&.[]('description').to_s).presence&.length.to_i,
                v
              ) * (part || (v['weight'].is_a?(::Float) ? v['weight'] : v['weight'].to_r))
            end

            score
          end

          def by_name_and_presence(definition:, parameters:, key:, **_args)
            score = 0
            part = Rational(1, definition.dig('content_score', 'score_matrix').size) unless definition.dig('content_score', 'score_matrix').values.all? { |v| v&.key?('weight') }

            definition.dig('content_score', 'score_matrix').each do |k, v|
              score += (DataCycleCore::DataHashService.present?(parameters[key]&.find { |e| e['name'] == k }) ? 1 : 0) * (part || (v['weight'].is_a?(::Float) ? v['weight'] : v['weight'].to_r))
            end

            score
          end

          def to_tooltip(_content, definition, locale)
            case definition.dig('content_score', 'method')
            when 'by_name_and_length'
              tooltip = []
              base_string = tooltip_base_string('by_name_and_length', locale: locale)

              definition.dig('content_score', 'score_matrix')
                &.sort_by { |k, v| [-v&.dig('weight')&.to_r, k] }
                &.each do |k, v|
                sub_tip = []
                sub_tip.push("<b>#{k}</b> #{"(#{DataCycleCore::LocalizationService.view_helpers.number_with_precision(v['weight'].to_r * 100, precision: 1)}%)" if v.key?('weight')}")
                sub_tip.push("<ul><li>#{base_string}</li>")

                v.except('weight').each do |key, value|
                  sub_tip.push("<li>#{tooltip_string("score_matrix.#{key}", locale: locale, value: value)}</li>")
                end

                tooltip.push("#{sub_tip.join}</ul>")
              end

              tooltip.join
            else
              super
            end
          end

          private

          def calculate_nested_scores(objects:, definition:)
            template = DataCycleCore::Thing.find_by(template: true, template_name: definition['template_name'])
            contents = DataCycleCore::Thing.where(id: objects.pluck(:id)).index_by(&:id)

            return [] if template.nil?

            scores = []

            objects.each do |value|
              scores << (contents[value['id']] || template).calculate_content_score(nil, value)
            end

            scores.flatten!
            scores.compact!

            scores
          end
        end
      end
    end
  end
end
