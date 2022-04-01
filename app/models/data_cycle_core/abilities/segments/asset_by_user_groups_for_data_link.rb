# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class AssetByUserGroupsForDataLink < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Asset
        end

        def conditions
          { creator_id: user.include_groups_user_ids, type: 'DataCycleCore::TextFile' }
        end
      end
    end
  end
end
