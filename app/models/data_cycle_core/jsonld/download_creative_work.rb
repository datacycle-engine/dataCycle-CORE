module DataCycleCore
  module Jsonld

    class DownloadCreativeWork
      include Mongoid::Document
      store_in collection: "download_creative_works"

      field :external_id,  type: String
      field :dump,         type: Hash
      field :seen_at,      type: DateTime
      include Mongoid::Timestamps

      index({ starred: 1 })
    end

  end
end
