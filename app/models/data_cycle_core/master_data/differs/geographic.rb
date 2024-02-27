# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Geographic < Basic
        def epsilon
          1e-6
        end

        def diff(a, b, _template, _partial_update)
          geo_a = DataCycleCore::MasterData::DataConverter.string_to_geographic(a)
          geo_b = DataCycleCore::MasterData::DataConverter.string_to_geographic(b)
          @diff_hash = generic_diff(geo_a, geo_b, method(:geo_comp).to_proc)
        end

        def geo_comp(a, b)
          return true if a.blank? && b.blank?
          return false if a.blank? || b.blank?
          return true if a.coordinates == b.coordinates

          return ((a.x - b.x).abs < epsilon) && ((a.y - b.y).abs < epsilon) if a.geometry_type == RGeo::Feature::Point && b.geometry_type == RGeo::Feature::Point

          false
        end
      end
    end
  end
end
