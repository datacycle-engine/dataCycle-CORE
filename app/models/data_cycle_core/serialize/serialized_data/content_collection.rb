# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module SerializedData
      class ContentCollection
        include Enumerable

        attr_accessor :collection

        def initialize(collection)
          @collection = collection
        end

        def each(&)
          @collection.each(&)
        end
      end
    end
  end
end
