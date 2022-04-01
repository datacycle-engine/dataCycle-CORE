# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoImport
      class Endpoint
        def initialize(file: nil, **_options)
          @file = file
        end

        def tours(*)
          factory = RGeo::Geographic.simple_mercator_factory
          data = RGeo::GeoJSON.decode(File.read(Rails.root.join(@file)), geo_factory: factory)
          Enumerator.new do |yielder|
            data.each do |radweg|
              yielder << radweg.properties.merge({ 'tour' => radweg.geometry.to_s })
            end
          end
        end
      end
    end
  end
end
