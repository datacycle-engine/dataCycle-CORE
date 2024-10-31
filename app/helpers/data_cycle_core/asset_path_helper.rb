# frozen_string_literal: true

module DataCycleCore
  module AssetPathHelper
    def dc_image_path(filename)
      return if filename.blank?

      dc_vite_asset_url("images/#{filename}", true)
    end

    def dc_image_url(filename)
      return if filename.blank?

      dc_vite_asset_url("images/#{filename}")
    end

    def dc_background_image_style
      return if DataCycleCore.logo['background_images'].blank?

      "--dc-background-image-url: url('#{dc_image_path(Array.wrap(DataCycleCore.logo['background_images']).sample.to_s)}');"
    end

    def dc_stylesheet_tag(asset_name)
      asset_path = dc_vite_asset_url("entrypoints/#{asset_name}", true)

      tag.link(rel: 'stylesheet', media: 'screen', href: asset_path)
    end

    def dc_vite_asset_url(asset_path, path_only = false)
      return if asset_path.blank?

      method_name = path_only ? :vite_asset_path : :vite_asset_url

      if ViteRuby.instance.dev_server_running?
        return send(method_name, "/vendor/gems/data-cycle-core/app/assets/#{asset_path}") unless File.file?(ViteRuby.config.vite_root_dir.join(asset_path))
      elsif vite_manifest.send(:lookup, asset_path)&.dig('file').blank?
        return send(method_name, "/vendor/gems/data-cycle-core/app/assets/#{asset_path}")
      end

      send(method_name, asset_path)
    rescue ViteRuby::MissingEntrypointError => e
      ActiveSupport::Notifications.instrument 'vite_asset_path_error.datacycle', content: asset_path, exception: e

      asset_path
    end
  end
end
