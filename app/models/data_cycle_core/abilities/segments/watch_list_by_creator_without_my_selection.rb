# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class WatchListByCreatorWithoutMySelection < Base
        attr_reader :subject

        def initialize
          @subject = WatchList
        end

        def conditions
          { user_id: user&.id, my_selection: false }
        end
      end
    end
  end
end
