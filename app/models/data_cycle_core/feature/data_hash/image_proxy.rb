# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module ImageProxy
        def thumbnail_url
          return DataCycleCore::Feature::ImageProxy.process_image(content: self, variant: 'thumb') if DataCycleCore::Feature::ImageProxy.frontend_enabled? && DataCycleCore::Feature::ImageProxy.supported_content_type?(self)
          super
        end

        def asset_web_url
          return DataCycleCore::Feature::ImageProxy.process_image(content: self, variant: 'web') if DataCycleCore::Feature::ImageProxy.frontend_enabled? && DataCycleCore::Feature::ImageProxy.supported_content_type?(self)
          super
        end
      end
    end
  end
end
