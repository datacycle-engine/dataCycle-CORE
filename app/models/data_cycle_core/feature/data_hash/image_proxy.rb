# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module ImageProxy
        def respond_to?(method_name, include_all = false)
          return false if method_name == :thumbnail_url && property_definitions.try(:[], method_name.to_s).blank?
          return false if method_name == :asset_web_url && (!DataCycleCore::Feature::ImageProxy.frontend_enabled? || !DataCycleCore::Feature::ImageProxy.supported_content_type?(self))
          super
        end

        def thumbnail_url
          return super if template_name == 'Video' && !DataCycleCore.experimental_features.dig('active_storage', 'enabled')
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
