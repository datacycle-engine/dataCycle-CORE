module DataCycleCore
  module OutdoorActive

    class DownloadPoiUpsert
      include Mongoid::Document
      store_in collection: "download_pois_upsert"
    end

  end
end
