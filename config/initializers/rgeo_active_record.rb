# frozen_string_literal: true

RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  # Use a geographic implementation for multi_line_string columns.
  config.register(RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true, wkb_parser: { support_wkb12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 }), { geo_type: 'multi_line_string', srid: 4326, sql_type: 'geometry', has_z: true })
end
