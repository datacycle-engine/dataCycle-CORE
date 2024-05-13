# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class WatchListByUserShares < StoredFilterBySharedUsers
        def initialize(**)
          @subject = DataCycleCore::WatchList
        end
      end
    end
  end
end
