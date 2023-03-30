# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class WatchListByApi < Base
        attr_reader :subject, :conditions

        def initialize
          @subject = DataCycleCore::WatchList
          @conditions = { my_selection: false, api: true }
        end
      end
    end
  end
end
