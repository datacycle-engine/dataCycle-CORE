# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Geocode < Base
      class << self
        def address_source(content)
          attribute_keys(content).first
        end
      end
    end
  end
end
