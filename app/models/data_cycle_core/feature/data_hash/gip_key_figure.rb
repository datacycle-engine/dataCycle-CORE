# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module GipKeyFigure
        def get_key_figure(_part_ids, _key = nil)
          # for demo purposes return random number between 100 and 1000
          rand(100...1000)
        end
      end
    end
  end
end
