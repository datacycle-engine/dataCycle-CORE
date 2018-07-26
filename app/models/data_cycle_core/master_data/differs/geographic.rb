# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Geographic < BasicDiffer
        def diff(a, b, _template)
          geo_a = DataCycleCore::MasterData::DataConverter.string_to_geographic(a)
          geo_b = DataCycleCore::MasterData::DataConverter.string_to_geographic(b)
          @diff_hash = basic_diff(geo_a, geo_b)
        end
      end
    end
  end
end
