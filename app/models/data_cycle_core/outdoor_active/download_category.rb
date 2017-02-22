module DataCycleCore
  module OutdoorActive

    class DownloadCategory
      include Mongoid::Document
      store_in collection: "download_categories"

      field :name,      type: String
      field :parent_id, type: String
      field :dump,      type: Hash
      field :seen_at,   type: DateTime
      include Mongoid::Timestamps

      index({ starred: 1 })
    end

  end
end
