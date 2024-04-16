# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterBySharedUserGroups < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::StoredFilter
        end

        def conditions
          { shared_user_groups: { id: user.user_groups.pluck(:id) } }
        end
      end
    end
  end
end
