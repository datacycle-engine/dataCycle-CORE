# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Datetime < Basic
        def diff(a, b, _template, _partial_update)
          datetime_a = DataCycleCore::MasterData::DataConverter.string_to_datetime(a)
          datetime_b = DataCycleCore::MasterData::DataConverter.string_to_datetime(b)
          @diff_hash = basic_diff(datetime_a, datetime_b)
        end
      end
    end
  end
end
