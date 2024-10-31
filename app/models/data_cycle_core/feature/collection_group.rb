# frozen_string_literal: true

module DataCycleCore
  module Feature
    class CollectionGroup < Base
      class << self
        def separator
          configuration['separator']
        end
      end
    end
  end
end
