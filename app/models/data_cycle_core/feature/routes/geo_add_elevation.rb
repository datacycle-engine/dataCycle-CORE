# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module GeoAddElevation
        def self.extend(router)
          router.instance_exec do
            post '/things/geo_add_elevation', action: :geo_add_elevation, controller: 'things', as: 'geo_add_elevation_things'
          end
        end
      end
    end
  end
end
