# frozen_string_literal: true

module DataCycleCore
  module Feature
    class OverlayAttributeService < BaseService
      private

      def process
        DataCycleCore::Feature::Overlay.allowed_attribute_keys(@content)
      end
    end
  end
end
