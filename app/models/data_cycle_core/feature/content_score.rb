# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ContentScore < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::ContentScore
        end

        def allowed?(content = nil)
          enabled? && configuration(content).dig('module').present? && configuration(content).dig('method').present?
        end

        def definition(key, content)
          return content.properties_for(key)&.with_indifferent_access unless key.nil?

          return unless allowed?(content)

          definition = ActiveSupport::HashWithIndifferentAccess.new(content_score: configuration(content).except(:enabled, :allowed))
          definition['content_score']['parameters'] = content&.content_score_property_names if definition&.dig('content_score', 'parameters') == 'content_score_property_names'

          definition
        end
      end
    end
  end
end
