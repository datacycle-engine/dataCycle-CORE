# frozen_string_literal: true

module DataCycleCore
  module AssetPathHelper
    def dc_image_path(filename)
      return if filename.blank?

      vite_asset_path("images/#{filename}")
    end

    def dc_background_image_style
      return if DataCycleCore.logo.dig('background_images').blank?

      "--dc-background-image-url: url('#{dc_image_path(Array.wrap(DataCycleCore.logo.dig('background_images')).sample.to_s)}');"
    end
  end
end
