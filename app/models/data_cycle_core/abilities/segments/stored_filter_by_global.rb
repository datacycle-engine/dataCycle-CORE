# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      # Legacy Segment, should be deleted, after all permissions are up to date
      class StoredFilterByGlobal < Base
        attr_reader :subject, :conditions

        def initialize
          @subject = StoredFilter
          @conditions = {}
        end
      end
    end
  end
end
