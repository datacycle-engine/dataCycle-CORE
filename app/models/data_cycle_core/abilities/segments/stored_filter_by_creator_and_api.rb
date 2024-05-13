# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByCreatorAndApi < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::StoredFilter
        end

        def conditions
          { user_id: user&.id, api: true }
        end
      end
    end
  end
end
