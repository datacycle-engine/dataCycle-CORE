# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class CollectionByApiAndSharedUserGroups < CollectionBySharedUserGroups
        def conditions
          super.merge({ api: true })
        end
      end
    end
  end
end
