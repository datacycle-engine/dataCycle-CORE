# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Image
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
        end
      end
    end
  end
end
