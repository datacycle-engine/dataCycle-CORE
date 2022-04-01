# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Boolean < Basic
        def diff(a, b, _template, _partial_update)
          bool_a = DataCycleCore::MasterData::DataConverter.string_to_boolean(a)
          bool_b = DataCycleCore::MasterData::DataConverter.string_to_boolean(b)
          @diff_hash = basic_diff(bool_a, bool_b)
        end
      end
    end
  end
end
