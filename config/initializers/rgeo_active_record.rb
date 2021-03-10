# frozen_string_literal: true

RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  # By default, use the GEOS implementation for spatial columns.
  config.default = RGeo::Geos.factory_generator

  config.register(RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true, wkb_parser: { support_wkb12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 }), geo_type: 'MultiLineString', srid: 4326, sql_type: 'geometry(MultiLineStringZ,4326)', has_z: true)
end
