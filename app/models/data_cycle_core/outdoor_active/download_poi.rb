module DataCycleCore
  module OutdoorActive

    class DownloadPoi
      include Mongoid::Document

      field :title,        type: String
      field :lastModified, type: DateTime
      field :dump,         type: Hash
      field :seen_at,      type: DateTime
      include Mongoid::Timestamps

      index({ starred: 1 })
    end

  end
end
