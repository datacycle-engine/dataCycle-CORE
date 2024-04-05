# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByGlobal < Base
        attr_reader :subject, :conditions

        def initialize
          @subject = StoredFilter
          @conditions = { system: true }
        end
      end
    end
  end
end
