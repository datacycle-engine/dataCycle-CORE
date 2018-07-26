# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Key < BasicDiffer
        def diff(a, b, _template)
          @diff_hash = basic_diff(a, b)
        end
      end
    end
  end
end
