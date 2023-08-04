# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      module Refresh
        include Functions

        def self.process(utility_object:, options:)
          Functions.refresh(utility_object:, options:)
        end
      end
    end
  end
end
