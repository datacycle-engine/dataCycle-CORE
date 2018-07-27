# frozen_string_literal: true

module DataCycleCore
  class PlacesController < ContentsController
    private

    def before_set_data_hash(datahash)
      # geo_location datahash
      datahash
    end

    def geo_location(datahash)
      datahash['location'] = RGeo::Geographic.spherical_factory(srid: 4326).point(datahash['longitude'].to_f, datahash['latitude'].to_f) if !datahash['longitude'].nil? && datahash['longitude'].present? && !datahash['latitude'].nil? && datahash['latitude'].present?
      datahash
    end
  end
end
