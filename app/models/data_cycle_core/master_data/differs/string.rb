# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class String < Basic
        def diff(a, b, _template, _partial_update)
          string_a = DataCycleCore::MasterData::DataConverter.string_to_string(a)
          string_b = DataCycleCore::MasterData::DataConverter.string_to_string(b)
          @diff_hash = basic_diff(string_a, string_b)
        end
      end
    end
  end
end
