# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Overlay < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::Overlay
        end
      end
    end
  end
end
