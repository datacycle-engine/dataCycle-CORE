# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Geocode < Base
      class << self
        def address_source(content)
          attribute_keys(content).first
        end

        def allowed?(content = nil) # rubocop:disable Lint/UnusedMethodArgument
          enabled?
        end
      end
    end
  end
end
