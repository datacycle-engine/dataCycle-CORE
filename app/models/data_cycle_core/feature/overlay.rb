# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Overlay < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::Overlay
        end

        def attribute_keys(content = nil)
          overlay_attribute_keys = configuration['attribute_keys'] || [] # only return "overlay" for legacy purposes
          return overlay_attribute_keys if overlay_attribute_keys.blank? || content.nil?

          return [] unless content.respond_to?(overlay_attribute_keys.first&.to_sym)

          overlay_attribute_keys
        end
      end
    end
  end
end
