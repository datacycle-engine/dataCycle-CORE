# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class LifeCycleIsEditable < ContentIsEditable
        def include?(content, scope = nil)
          return false if content.try(:data_pool_imported)

          super
        end
      end
    end
  end
end
