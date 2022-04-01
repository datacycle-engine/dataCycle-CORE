# frozen_string_literal: true

# @todo: check if obsolete after avtive storage migration
module DataCycleCore
  module AssetHelpers
    def thumbnail_url?
      true if send(:thumb_preview).present?
    end

    def thumbnail_url
      send(:thumb_preview).url if thumbnail_url?
    end

    def headline
      ''
    end
  end
end
