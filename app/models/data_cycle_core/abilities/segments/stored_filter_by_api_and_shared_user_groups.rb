# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByApiAndSharedUserGroups < CollectionByApiAndSharedUserGroups
        def initialize
          @subject = DataCycleCore::StoredFilter
        end
      end
    end
  end
end
