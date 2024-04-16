# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterBySharedUsers < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::StoredFilter
        end

        def conditions
          { shared_users: { id: user.id } }
        end
      end
    end
  end
end
