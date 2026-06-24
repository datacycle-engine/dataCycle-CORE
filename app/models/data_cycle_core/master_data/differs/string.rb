# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class String < Basic
        def diff(a, b, template, _partial_update)
          string_a = DataCycleCore::MasterData::DataConverter.convert_to_string('string', a, template)
          string_b = DataCycleCore::MasterData::DataConverter.convert_to_string('string', b, template)
          @diff_hash = basic_diff(string_a, string_b)
        end
      end
    end
  end
end
