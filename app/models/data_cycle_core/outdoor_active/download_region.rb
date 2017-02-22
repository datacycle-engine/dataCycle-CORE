module DataCycleCore
  module OutdoorActive

    class DownloadRegion
      include Mongoid::Document

      field :name,          type: String
      field :region_id,     type: String
      field :parent_id,     type: String
      field :level,         type: Integer
      field :regionType,    type: String
      field :categoryId,    type: Integer
      field :categoryTitle, type: String
      field :hasTour,       type: String
      field :bbox,          type: String
      field :seen_at,       type: DateTime
      include Mongoid::Timestamps

      index({ starred: 1 })

    end

  end
end
