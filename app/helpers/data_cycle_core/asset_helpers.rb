module DataCycleCore
  module AssetHelpers
    def thumbnail_url
      file.thumb_preview.url
    end

    def headline
      ''
    end
  end
end
