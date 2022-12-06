# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Classification < UuidSet
        def diff(a, b, _template, _partial_update)
          ids_a = parse_uuids(a)
          ids_b = parse_uuids(b)
          @diff_hash = set_diff(ids_a&.sort, ids_b&.sort)
        end
      end
    end
  end
end
