# frozen_string_literal: true

module DataCycleCore
  module AssetHelpers
    def thumbnail_url?
      true if !file.try(:thumb_preview).nil? && !file.thumb_preview.file.nil? && file.thumb_preview.file.exists?
    end

    def thumbnail_url
      file.thumb_preview.url if thumbnail_url?
    end

    def headline
      ''
    end
  end
end
