# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ContentLock < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::ContentLock
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::ContentLock
        end

        def lock_length
          configuration.dig('lock_length')
        end

        def lock_renew_before
          configuration.dig('lock_renew_before')
        end
      end
    end
  end
end
