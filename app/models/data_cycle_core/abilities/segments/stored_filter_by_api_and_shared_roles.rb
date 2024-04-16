# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByApiAndSharedRoles < StoredFilterBySharedRoles
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::StoredFilter
        end

        def conditions
          super.merge({ api: true })
        end
      end
    end
  end
end
