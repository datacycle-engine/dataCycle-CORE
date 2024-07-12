# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Overlay < Base
      class << self
        def attribute_keys(_content = nil)
          configuration.dig('attribute_keys') || [] # only return "overlay" for legacy purposes
        end
      end
    end
  end
end
