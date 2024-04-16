# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class WatchListByUserShares < Base
        attr_reader :subject

        def initialize(**)
          @subject = DataCycleCore::WatchList
        end

        def conditions
          {
            collection_shares: {
              shareable_id: user.id,
              shareable_type: 'DataCycleCore::User'
            },
            my_selection: false
          }
        end
      end
    end
  end
end
