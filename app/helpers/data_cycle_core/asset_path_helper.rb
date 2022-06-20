# frozen_string_literal: true

module DataCycleCore
  module AssetPathHelper
    def dc_image_path(filename)
      return if filename.blank?

      return vite_asset_path("/vendor/gems/data-cycle-core/app/assets/images/#{filename}") if ViteRuby.instance.dev_server_running? && ViteRuby.instance.manifest.send(:manifest)[ViteRuby.instance.manifest.send(:resolve_entry_name, "images/#{filename}")].nil?

      vite_asset_path("images/#{filename}")
    rescue ViteRuby::MissingEntrypointError
      begin
        vite_asset_path("/vendor/gems/data-cycle-core/app/assets/images/#{filename}")
      rescue ViteRuby::MissingEntrypointError => e
        ActiveSupport::Notifications.instrument 'vite_asset_path_error.datacycle', content: filename, exception: e

        filename
      end
    end

    def dc_background_image_style
      return if DataCycleCore.logo.dig('background_images').blank?

      "--dc-background-image-url: url('#{dc_image_path(Array.wrap(DataCycleCore.logo.dig('background_images')).sample.to_s)}');"
    end
  end
end
