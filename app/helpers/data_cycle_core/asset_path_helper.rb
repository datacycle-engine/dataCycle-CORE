# frozen_string_literal: true

module DataCycleCore
  module AssetPathHelper
    def dc_image_path(filename)
      return if filename.blank?

      vite_asset_path("images/#{filename}")
    end
  end
end
