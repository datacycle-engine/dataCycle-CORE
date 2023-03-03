# frozen_string_literal: true

module DataCycleCore
  module AssetPathHelper
    def dc_image_path(filename)
      return if filename.blank?

      dc_vite_asset_path("images/#{filename}")
    end

    def dc_background_image_style
      return if DataCycleCore.logo.dig('background_images').blank?

      "--dc-background-image-url: url('#{dc_image_path(Array.wrap(DataCycleCore.logo.dig('background_images')).sample.to_s)}');"
    end

    def dc_stylesheet_tag(asset_name)
      asset_path = dc_vite_asset_path("entrypoints/#{asset_name}")

      tag.link(rel: 'stylesheet', media: 'screen', href: asset_path)
    end

    def dc_vite_asset_path(asset_path)
      return if asset_path.blank?

      if ViteRuby.instance.dev_server_running?
        return vite_asset_path("/vendor/gems/data-cycle-core/app/assets/#{asset_path}") unless File.file?(ViteRuby.config.vite_root_dir.join(asset_path))

        vite_asset_path("/#{asset_path}")
      end

      vite_asset_path(asset_path)
    rescue ViteRuby::MissingEntrypointError
      begin
        vite_asset_path("/vendor/gems/data-cycle-core/app/assets/#{asset_path}")
      rescue ViteRuby::MissingEntrypointError => e
        ActiveSupport::Notifications.instrument 'vite_asset_path_error.datacycle', content: asset_path, exception: e

        asset_path
      end
    end
  end
end
