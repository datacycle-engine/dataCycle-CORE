# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class WatchListByUserShares < Base
        attr_reader :subject, :additional_conditions

        def initialize(**additional_conditions)
          @subject = DataCycleCore::WatchList
          @additional_conditions = additional_conditions
        end

        def conditions
          { watch_list_shares: { shareable_id: user.id, shareable_type: 'DataCycleCore::User' } }.merge(additional_conditions)
        end
      end
    end
  end
end
