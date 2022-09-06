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
