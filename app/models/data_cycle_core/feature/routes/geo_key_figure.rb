# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module GeoKeyFigure
        def self.extend(router)
          router.instance_exec do
            post '/things/:id/geo_key_figure', action: :geo_key_figure, controller: 'things', as: 'geo_key_figure_thing'
          end
        end
      end
    end
  end
end
