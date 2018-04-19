module DataCycleCore
  module Feature
    class OverlayAttributeService < BaseService
      private

      def process
        overlay_feature = DataCycleCore::Feature::Overlay.new(content: @content)
        overlay_feature.attribute_keys
      end
    end
  end
end
