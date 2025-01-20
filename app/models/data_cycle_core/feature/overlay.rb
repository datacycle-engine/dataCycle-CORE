# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Overlay < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::Overlay
        end

        def attribute_keys(_content = nil)
          configuration['attribute_keys'] || [] # only return "overlay" for legacy purposes
        end
      end
    end
  end
end
