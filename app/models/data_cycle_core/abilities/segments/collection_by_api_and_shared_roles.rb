# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class CollectionByApiAndSharedRoles < CollectionBySharedRoles
        def conditions
          super.merge({ api: true })
        end
      end
    end
  end
end
