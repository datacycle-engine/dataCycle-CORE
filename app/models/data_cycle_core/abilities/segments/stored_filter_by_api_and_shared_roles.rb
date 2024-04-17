# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByApiAndSharedRoles < CollectionByApiAndSharedRoles
        def initialize
          @subject = DataCycleCore::StoredFilter
        end
      end
    end
  end
end
