# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module ContentScore
        def content_score_property_names(include_overlay = false)
          name_property_selector(include_overlay) { |definition| definition['content_score'].present? }
        end

        def ordered_content_score_property_names(include_overlay = false)
          content_score_property_names(include_overlay).sort_by { |k| properties_for(k)&.[]('sorting') }
        end

        def content_score_parameters
          schema&.dig('features', 'content_score', 'parameters')
        end

        def calculate_content_score(key, datahash)
          DataCycleCore::Utility::ContentScore::Base.calculate_content_score(key, datahash, self)
        end

        def content_score_allowed?
          DataCycleCore::Feature::ContentScore.allowed?(self)
        end

        def content_score_definition(key)
          DataCycleCore::Feature::ContentScore.definition(key, self)
        end
      end
    end
  end
end
