# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Table < Basic
        def diff(a, b, _template, _partial_update)
          @diff_hash = basic_diff(a, b)
        end
      end
    end
  end
end
