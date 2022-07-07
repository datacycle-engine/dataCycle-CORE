# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Geographic
        class << self
          def line_string_union(virtual_parameters:, content:, **_args)
            longlat_projection = RGeo::CoordSys::Proj4.new('EPSG:4326')
            factory = RGeo::Cartesian.factory(srid: 4326, proj4: longlat_projection)

            all_line_strings = content
              .send(virtual_parameters[0])
              .to_a
              .map { |i| i.send(virtual_parameters[1]) }
              .map { |i| i.is_a?(RGeo::Feature::MultiLineString) ? i.to_a : i }
              .flatten

            factory.multi_line_string(all_line_strings) if all_line_strings.present?
          end
        end
      end
    end
  end
end
