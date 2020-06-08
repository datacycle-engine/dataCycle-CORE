# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Asset < UuidSet
        def diff(a, b, _template)
          @diff_hash = basic_diff(parse_uuid(a), parse_uuid(b))
        end
      end
    end
  end
end
