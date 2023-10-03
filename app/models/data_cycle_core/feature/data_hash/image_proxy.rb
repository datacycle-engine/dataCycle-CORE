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
          return DataCycleCore::Feature::ImageProxy.process_image(content: self, variant: 'thumb') if DataCycleCore::Feature::ImageProxy.frontend_enabled? && ['Bild', 'ImageVariant'].include?(template_name)
          super
        end

        def asset_web_url
          return DataCycleCore::Feature::ImageProxy.process_image(content: self, variant: 'web') if DataCycleCore::Feature::ImageProxy.frontend_enabled? && ['Bild', 'ImageVariant'].include?(template_name)
          super
        end
      end
    end
  end
end
