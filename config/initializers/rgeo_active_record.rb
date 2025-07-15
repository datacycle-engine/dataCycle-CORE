# frozen_string_literal: true

RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  # Use a geographic implementation for multi_line_string columns.
  # RGeo::Geographic.spherical_factory seems to be the only one that works with Rails Dirty Tracking for Z-Coordinates.
  # Other Factories treat Point Z (2.0 2.0 1.0) as equal to Point Z (2.0 2.0 0.0) and do not track/save changes.
  config.register(
    RGeo::Geographic.spherical_factory(
      srid: 4326,
      has_z_coordinate: true,
      uses_lenient_assertions: true,
      wkb_parser: { support_wkb12: true },
      wkt_generator: { convert_case: :upper, tag_format: :wkt12 }
    ),
    { geo_type: 'geometry', srid: 4326, sql_type: 'geometry', has_z: true }
  )

  config.register(
    RGeo::Geographic.spherical_factory(
      srid: 4326,
      uses_lenient_assertions: true,
      wkb_parser: { support_wkb12: true },
      wkt_generator: { convert_case: :upper, tag_format: :wkt12 }
    ),
    { geo_type: 'geometry', srid: 4326, sql_type: 'geometry' }
  )
end
