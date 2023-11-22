# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Content
        extend Extensions::Tooltip

        class << self
          def by_minimum(content:, parameters:, **_args)
            scores = Base.calculate_scores_by_method_or_presence(content:, parameters:).values

            scores.flatten!
            scores.compact!

            scores.min
          end

          def by_weight_matrix(content:, parameters:, definition:, **_args)
            scores = Base.calculate_scores_by_method_or_presence(content:, parameters:)

            definition.dig('content_score', 'weight_matrix')&.sum { |k, v| scores[k].to_f * v.to_r }
          end

          def by_field_presence_or_method(content:, parameters:, definition:, **_args)
            max_value = 1.0
            rating_factor = max_value / parameters.size
            min_value = 0

            scores = Base.calculate_scores_by_method_or_presence(content:, parameters:)

            definition.dig('content_score', 'score_matrix').each do |max, property_names|
              required = property_names.size
              actual = scores.values_at(*property_names).count { |v| v&.>(0) }
              max_value = [max_value, max.to_f].min unless actual == required
            end

            return max_value if max_value == min_value

            actual = scores.values.count { |v| v&.>(0) }

            [actual * rating_factor, max_value].min
          end

          def by_field_presence(parameters:, definition:, **_args)
            max_value = 1.0
            rating_factor = max_value / parameters.size
            min_value = 0

            definition.dig('content_score', 'score_matrix').each do |max, property_names|
              actual, required = Base.values_present(parameters, property_names)

              max_value = [max_value, max.to_f].min unless actual == required
            end

            return max_value if max_value == min_value

            actual, _required = Base.values_present(parameters, parameters.keys)

            [actual * rating_factor, max_value].min
          end

          def to_tooltip(content, definition, locale)
            tooltip = [tooltip_base_string(definition.dig('content_score', 'method'), locale:)]

            if definition.dig('content_score', 'weight_matrix').present?
              subtips = ['<ul>']
              definition.dig('content_score', 'weight_matrix')
                .sort_by { |k, _v| content.properties_for(k)&.[]('sorting') }
                .each do |k, v|
                subtips.push("<li><b>#{content.class.human_attribute_name(k, { base: content, definition: content.properties_for(k), locale: })}</b> (#{(v.to_r * 100).round}%)</li>")
              end
              tooltip.push("#{subtips.join}</ul>")
            end

            if definition.dig('content_score', 'score_matrix').present?
              subtips = ['<ul>']

              definition.dig('content_score', 'parameters')
                .map { |n| n.split('.').first }
                .uniq
                .sort_by { |name| content.properties_for(name)&.[]('sorting') }
                .each do |name|
                subtips.push("<li><b>#{content.class.human_attribute_name(name, { base: content, definition: content.properties_for(name), locale: })}</b></li>")
              end

              tooltip.push("#{subtips.join}</ul>")

              definition.dig('content_score', 'score_matrix').each do |k, v|
                subtips = ['<ul>']
                subtips.push("<li>#{tooltip_string('score_matrix', max: (k.to_f * 100).round, locale:)}</li><ul>")

                v.map { |n| n.split('.').first }
                  .uniq
                  .sort_by { |name| content.properties_for(name)&.[]('sorting') }
                  .each do |name|
                  subtips.push("<li><b>#{content.class.human_attribute_name(name, { base: content, definition: content.properties_for(name), locale: })}</b></li>")
                end

                tooltip.push("#{subtips.join}</ul></ul>")
              end
            end

            tooltip.compact.join('<br>')
          end
        end
      end
    end
  end
end
