# frozen_string_literal: true

# @todo: check if obsolete after avtive storage migration
module DataCycleCore
  module AssetHelpers
    def thumbnail_url?
      if self.class.active_storage_activated?
        true if send(:thumb_preview).present?
      elsif !file.try(:thumb_preview).nil? && !file.thumb_preview.file.nil? && file.thumb_preview.file.exists?
        true
      end
    end

    def thumbnail_url
      if self.class.active_storage_activated?
        send(:thumb_preview).url if thumbnail_url?
      elsif thumbnail_url?
        file.thumb_preview.url
      end
    end

    def headline
      ''
    end
  end
end
