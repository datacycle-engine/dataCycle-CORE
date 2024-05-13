# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByApi < Base
        attr_reader :subject, :conditions

        def initialize
          @subject = StoredFilter
          @conditions = { api: true }
        end
      end
    end
  end
end
