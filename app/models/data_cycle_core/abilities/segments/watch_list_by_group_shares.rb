# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class WatchListByGroupShares < Base
        attr_reader :subject, :additional_conditions

        def initialize(**additional_conditions)
          @subject = DataCycleCore::WatchList
          @additional_conditions = additional_conditions
        end

        def conditions
          { watch_list_shares: { shareable_id: user.user_group_ids, shareable_type: 'DataCycleCore::UserGroup' } }.merge(additional_conditions)
        end
      end
    end
  end
end
