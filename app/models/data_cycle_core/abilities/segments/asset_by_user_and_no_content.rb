# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class AssetByUserAndNoContent < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Asset
        end

        def conditions
          { creator_id: user&.id, asset_content: { id: nil } }
        end
      end
    end
  end
end
