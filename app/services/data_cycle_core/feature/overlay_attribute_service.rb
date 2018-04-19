module DataCycleCore
  module Feature
    class OverlayAttributeService < BaseService
      private

      def process
        DataCycleCore::Feature::Overlay.attribute_keys(@content)
      end
    end
  end
end
