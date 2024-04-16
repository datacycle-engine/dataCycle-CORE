# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class WatchListByGroupShares < Base
        # except my_selection
        attr_reader :subject

        def initialize(**)
          @subject = DataCycleCore::WatchList
        end

        def conditions
          {
            collection_shares: {
              shareable_id: user.user_group_ids,
              shareable_type: 'DataCycleCore::UserGroup'
            },
            my_selection: false
          }
        end
      end
    end
  end
end
