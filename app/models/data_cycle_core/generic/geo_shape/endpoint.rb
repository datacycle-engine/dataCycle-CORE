# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoShape
      class Endpoint
        def initialize(storage_type: 'local', directory: nil, delete: false, options: {}, **_args)
          @storage_type = storage_type
          @delete = delete
          @srid = options[:srid].presence || 4326
          @folder_path = File.join(directory, options[:folder_path].presence || options[:name], '**', '*.shp')
          @factory_source = RGeo::Geos.factory(srid: @srid, proj4: RGeo::CoordSys::Proj4.new("EPSG:#{@srid}"))
          @factory4326 = RGeo::Geos.factory(srid: 4326, proj4: RGeo::CoordSys::Proj4.new('EPSG:4326'))
        end

        def shp(*)
          Enumerator.new do |yielder|
            load_data(&yielder)
          end
        end

        private

        def load_data
          Dir[@folder_path].each do |shapefile|
            RGeo::Shapefile::Reader.open(shapefile, { factory: @factory_source }) do |file|
              file.each do |record|
                yield({ **record.attributes, 'geom' => RGeo::Feature.cast(record.geometry, factory: @factory4326, project: true).to_s })
              end
            end
          end
        end
      end
    end
  end
end
