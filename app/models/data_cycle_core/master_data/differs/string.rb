# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class String < Basic
        def diff(a, b, template)
          string_a = DataCycleCore::MasterData::DataConverter.string_to_string(a || load_value(template&.dig('default_value')))
          string_b = DataCycleCore::MasterData::DataConverter.string_to_string(b || load_value(template&.dig('default_value')))
          @diff_hash = basic_diff(string_a, string_b)
        end
      end
    end
  end
end
