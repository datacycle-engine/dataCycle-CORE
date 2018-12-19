# frozen_string_literal: true

module DataCycleCore
  module Warning
    class Bild < Base
      class << self
        def valid_until(params, content, context = nil)
          false
        end
      end
    end
  end
end
