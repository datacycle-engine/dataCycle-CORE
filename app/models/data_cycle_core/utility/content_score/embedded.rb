# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Embedded
        extend Extensions::Tooltip

        class << self
          def minimum(definition:, parameters:, key:, **_args)
            scores = calculate_nested_scores(definition:, objects: parameters&.[](key))

            scores.min
          end

          def by_name_and_length(definition:, parameters:, key:, **_args)
            score = 0
            part = Rational(1, definition.dig('content_score', 'score_matrix').size) unless definition.dig('content_score', 'score_matrix').values.all? { |v| v&.key?('weight') }

            definition.dig('content_score', 'score_matrix').each do |k, v|
              score += Base.score_by_quantity(
                ActionView::Base.full_sanitizer.sanitize(parameters&.[](key)&.find { |e| e['name'] == k }&.[]('description').to_s).presence&.length.to_i,
                v
              ) * (part || (v['weight'].is_a?(::Float) ? v['weight'] : v['weight'].to_r))
            end

            score
          end

          def by_name_and_presence(definition:, parameters:, key:, **_args)
            score = 0
            part = Rational(1, definition.dig('content_score', 'score_matrix').size) unless definition.dig('content_score', 'score_matrix').values.all? { |v| v&.key?('weight') }

            definition.dig('content_score', 'score_matrix').each do |k, v|
              score += (DataCycleCore::DataHashService.present?(parameters&.[](key)&.find { |e| e['name'] == k }) ? 1 : 0) * (part || (v['weight'].is_a?(::Float) ? v['weight'] : v['weight'].to_r))
            end

            score
          end

          def by_type_and_presence(definition:, parameters:, key:, **_args)
            score = 0
            part = Rational(1, definition.dig('content_score', 'score_matrix').size) unless definition.dig('content_score', 'score_matrix').values.all? { |v| v&.key?('weight') }

            definition.dig('content_score', 'score_matrix').each do |k, v|
              type_of_information = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Informationstypen', k)

              score += (DataCycleCore::DataHashService.present?(parameters&.[](key)&.find { |e| e['type_of_information']&.include?(type_of_information) || e['universal_classifications']&.include?(type_of_information) }) ? 1 : 0) * (part || (v['weight'].is_a?(::Float) ? v['weight'] : v['weight'].to_r))
            end

            score
          end

          def by_type_and_length(definition:, parameters:, key:, **_args)
            score = 0
            part = Rational(1, definition.dig('content_score', 'score_matrix').size) unless definition.dig('content_score', 'score_matrix').values.all? { |v| v&.key?('weight') }

            definition.dig('content_score', 'score_matrix').each do |k, v|
              type_of_information = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Informationstypen', k)

              score += Base.score_by_quantity(
                ActionView::Base.full_sanitizer.sanitize(parameters&.[](key)&.find { |e| e['type_of_information']&.include?(type_of_information) || e['universal_classifications']&.include?(type_of_information) }&.[]('description').to_s).presence&.length.to_i,
                v
              ) * (part || (v['weight'].is_a?(::Float) ? v['weight'] : v['weight'].to_r))
            end

            score
          end

          def to_tooltip(_content, definition, locale)
            case definition.dig('content_score', 'method')
            when 'by_type_and_length', 'by_type_and_presence'
              tooltip = [tooltip_base_string(definition.dig('content_score', 'method'), locale:)]

              if definition.dig('content_score', 'score_matrix').present?
                subtips = ['<ul>']

                definition.dig('content_score', 'score_matrix')
                  &.sort_by { |k, v| [-v&.dig('weight')&.to_r, k] }
                  &.each do |k, v|
                    nested_tip = []
                    nested_tip.push("<b>#{k}</b> #{"(#{DataCycleCore::LocalizationService.view_helpers.number_with_precision(v['weight'].to_r * 100, precision: 1)}%)" if v.key?('weight')}")

                    nested_tip.push('<ul>')

                    v.except('weight').each do |key, value|
                      nested_tip.push("<li>#{tooltip_string("score_matrix.#{key}", locale:, value:)}</li>")
                    end

                    subtips.push("<li>#{nested_tip.join}</ul></li>")
                  end

                subtips.push('</ul>')
                tooltip.push(subtips.join)
              end
            when 'by_name_and_length', 'by_name_and_presence'
              tooltip = []
              base_string = tooltip_base_string(definition.dig('content_score', 'method'), locale:)

              definition.dig('content_score', 'score_matrix')
                &.sort_by { |k, v| [-v&.dig('weight')&.to_r, k] }
                &.each do |k, v|
                sub_tip = []
                sub_tip.push("<b>#{k}</b> #{"(#{DataCycleCore::LocalizationService.view_helpers.number_with_precision(v['weight'].to_r * 100, precision: 1)}%)" if v.key?('weight')}")
                sub_tip.push("<ul><li>#{base_string}</li>")

                v.except('weight').each do |key, value|
                  sub_tip.push("<li>#{tooltip_string("score_matrix.#{key}", locale:, value:)}</li>")
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
            template = DataCycleCore::Thing.new(template_name: definition['template_name'])
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
