# frozen_string_literal: true

module DataCycleCore
  module DownloadHelpers
    def available_download_serializers(content)
      case content.class.to_s
      when 'DataCycleCore::WatchList'
        DataCycleCore::Feature::Download.available_collection_serializers('watch_list')
      when 'DataCycleCore::StoredFilter'
        DataCycleCore::Feature::Download.available_collection_serializers('stored_filter')
      else
        DataCycleCore::Feature::Serialize.available_serializers(content)
      end
    end
  end
end
