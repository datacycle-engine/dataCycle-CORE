# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Geocode < Base
      class << self
        def address_source(content)
          content&.schema&.dig('features', name.demodulize.underscore)
        end
      end
    end
  end
end
