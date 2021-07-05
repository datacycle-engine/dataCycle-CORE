# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Date < Basic
        def diff(a, b, _template, _partial_update)
          date_a = DataCycleCore::MasterData::DataConverter.string_to_date(a)
          date_b = DataCycleCore::MasterData::DataConverter.string_to_date(b)
          @diff_hash = basic_diff(date_a, date_b)
        end
      end
    end
  end
end
