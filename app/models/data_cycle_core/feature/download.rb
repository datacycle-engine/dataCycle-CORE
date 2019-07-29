# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Download < Base
      class << self
        def allowed?(content = nil)
          enabled? && configuration(content).dig('allowed')
        end
      end
    end
  end
end
