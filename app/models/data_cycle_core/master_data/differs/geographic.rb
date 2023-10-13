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
          # special case to fix a problem with linestrings from gip with changed direction (#32435)
          if a.respond_to?(:coordinates) && b.respond_to?(:coordinates)
            return false unless a.coordinates.flatten[0..1] == b.coordinates.flatten[0..1]
          end

          return true if a == b
          return false if a.blank? || b.blank?
          if a.respond_to?(:geometry_type) &&
             b.respond_to?(:geometry_type) &&
             a.geometry_type == RGeo::Feature::Point &&
             b.geometry_type == RGeo::Feature::Point
            ((a.x - b.x).abs < epsilon) && ((a.y - b.y).abs < epsilon)
          end
        end
      end
    end
  end
end
