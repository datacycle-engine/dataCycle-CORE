# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Download < Base
      class << self
        def allowed?(content = nil)
          enabled? && configuration(content).dig('allowed') && content.respond_to?(:asset) && content.external_source.blank?
        end
      end
    end
  end
end
