# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class CollectionBySharedUserGroups < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Collection
        end

        def conditions
          { my_selection: false, shared_user_groups: { id: user.user_group_ids } }
        end
      end
    end
  end
end
