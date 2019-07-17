# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Datetime < Basic
        def diff(a, b, template)
          datetime_a = DataCycleCore::MasterData::DataConverter.string_to_datetime(a || load_value(template&.dig('default_value')))
          datetime_b = DataCycleCore::MasterData::DataConverter.string_to_datetime(b || load_value(template&.dig('default_value')))
          @diff_hash = basic_diff(datetime_a, datetime_b)
        end
      end
    end
  end
end
