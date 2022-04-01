# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Embedded
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
