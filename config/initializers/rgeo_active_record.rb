# frozen_string_literal: true

RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  # By default, use the GEOS implementation for spatial columns.
  config.default = RGeo::Geos.factory_generator

  # But use a geographic implementation for point columns.
  # config.register(RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 }), geo_type: 'multi_line_string')
  config.register(RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 }), geo_type: 'multi_line_string', sql_type: 'geometry', has_z: true)
end
