# frozen_string_literal: true

namespace :dc do
  namespace :geo do
    desc 'add elevation to routes with partial elevation data'
    task add_elevation: :environment do
      abort 'Feature not enabled' unless DataCycleCore::Feature['GeoAddElevation']&.enabled?

      exists_zero = <<-SQL.squish
        EXISTS (
          SELECT 1
          FROM ST_DumpPoints(things.line) AS points(geo_path, geom)
          WHERE ST_Z(points.geom) = 0
        )
      SQL

      exists_not_zero = <<-SQL.squish
        EXISTS (
          SELECT 1
          FROM ST_DumpPoints(things.line) AS points(geo_path, geom)
          WHERE ST_Z(points.geom) != 0
        )
      SQL

      things = DataCycleCore::Thing
        .where(external_source_id: nil)
        .where.not(line: nil)
        .where(exists_zero)
        .where(exists_not_zero)

      progress = ProgressBar.create(total: things.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      things.find_each do |thing|
        geojson = { type: 'Feature', geometry: RGeo::GeoJSON.encode(thing.line) }
        new_geojson = DataCycleCore::Feature::GeoAddElevation.add_elevation_values(geojson)

        datahash = DataCycleCore::DataHashService.flatten_datahash_value({ line: new_geojson.to_json }, thing.schema)

        thing.set_data_hash(data_hash: datahash)
        progress.increment
      rescue StandardError => e
        puts "Error: #{e.message}"
        progress.increment
      end
    end
  end
end
