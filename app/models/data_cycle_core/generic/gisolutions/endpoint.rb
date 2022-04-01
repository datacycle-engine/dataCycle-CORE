# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gisolutions
      class Endpoint
        def initialize(directory: nil, **options)
          @file = directory + options.dig(:options, :file)
        end

        def lifts(*)
          factory = RGeo::Geographic.simple_mercator_factory
          data = RGeo::GeoJSON.decode(File.read(Rails.root.join(@file)), geo_factory: factory)
          Enumerator.new do |yielder|
            data.each do |lift_data|
              yielder << lift_data.properties.merge({ 'geometry' => lift_data.geometry.as_text })
            end
          end
        end

        def slopes(*)
          factory = RGeo::Geographic.simple_mercator_factory
          data = RGeo::GeoJSON.decode(File.read(Rails.root.join(@file)), geo_factory: factory)
          Enumerator.new do |yielder|
            data.each do |slope_data|
              slope_hash = slope_data.properties.merge({ 'geometry' => slope_data.geometry.as_text })
              slope_hash['ski_area_gisolutions'] = slope_hash['ski_area_gisolution'] if slope_hash.key?('ski_area_gisolution')
              yielder << slope_hash
            end
          end
        end
      end
    end
  end
end
