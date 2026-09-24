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

      position = DataCycleCore.logo['background_position'].presence || 'center center'
      "--dc-background-image-url: url('#{dc_image_path(Array.wrap(DataCycleCore.logo['background_images']).sample.to_s)}'); --dc-background-image-position: #{position};"
    end

    # Logo filename for the requested variant, falling back to the other one when an
    # instance configures only `normal` or only `inverted`. Without the fallback the
    # <img> renders blank wherever a page asks for the variant that instance never set
    # (e.g. /schema and /api/config/openapi ask for `normal`, while many instances
    # configure only the `inverted` one the nav uses).
    def dc_logo_file(inverted: false)
      variant, fallback = inverted ? ['inverted', 'normal'] : ['normal', 'inverted']

      DataCycleCore.logo[variant].presence || DataCycleCore.logo[fallback]
    end

    # Logo filename for the print stylesheet. `print` is optional, so fall back to the
    # screen variant rather than printing no logo at all.
    def dc_print_logo_file(inverted: false)
      DataCycleCore.logo['print'].presence || dc_logo_file(inverted:)
    end

    def dc_favicon_link_tags
      return if DataCycleCore.logo['favicons'].blank?

      capture do
        Array.wrap(DataCycleCore.logo['favicons']).each do |favicon|
          concat favicon_link_tag(
            dc_image_path(favicon['src']),
            rel: 'icon',
            type: favicon['type'],
            sizes: favicon['sizes'],
            nonce: true
          )
        end
      end
    end

    def dc_stylesheet_tag(asset_name)
      asset_path = dc_vite_asset_url("entrypoints/#{asset_name}", true)

      tag.link(rel: 'stylesheet', media: 'screen', href: asset_path)
    end

    def dc_javascript_tag(asset_path)
      capture do
        unless ViteRuby.instance.dev_server_running?
          dc_vite_stylesheet_paths(asset_path).each do |css_href|
            concat tag.link(
              rel: 'stylesheet',
              media: 'screen',
              href: css_href,
              nonce: content_security_policy_nonce
            )
          end
        end

        concat tag.script(
          type: 'module',
          src: dc_vite_asset_url(asset_path, true),
          nonce: content_security_policy_nonce
        )
      end
    end

    # Ready-to-use hrefs for the CSS chunks emitted alongside a JS entry. The
    # manifest's `css` array holds built output filenames, not logical entry
    # names, so they must be resolved through the manifest entry resolver —
    # passing them straight to `vite_asset_path` treats them as lookup keys and
    # raises ViteRuby::MissingEntrypointError (only surfaces when the dev server
    # is off, e.g. in CI). Empty when the entry or its CSS is absent.
    def dc_vite_stylesheet_paths(asset_path)
      vite_manifest.resolve_entries(dc_vite_entry_name(asset_path), type: :javascript)[:stylesheets]
    rescue ViteRuby::MissingEntrypointError
      []
    end

    def dc_vite_asset_url(asset_path, path_only = false)
      return if asset_path.blank?

      method_name = path_only ? :vite_asset_path : :vite_asset_url

      send(method_name, dc_vite_entry_name(asset_path))
    rescue ViteRuby::MissingEntrypointError => e
      ActiveSupport::Notifications.instrument 'vite_asset_path_error.datacycle', content: asset_path, exception: e

      asset_path
    end

    # Entrypoints/assets shipped by the gem live outside the host Vite root, so
    # Vite keys them in the manifest by their relative source path
    # (`../../vendor/gems/data-cycle-core/...`). ViteRuby can only resolve that
    # when handed the path relative to the project root (leading slash), which
    # it converts back to the exact manifest key. For host-provided assets the
    # plain name resolves directly, so only fall back to the gem-prefixed path
    # when the asset is not present under the host Vite root / manifest.
    def dc_vite_entry_name(asset_path)
      if ViteRuby.instance.dev_server_running?
        return "/vendor/gems/data-cycle-core/app/assets/#{asset_path}" unless File.file?(ViteRuby.config.vite_root_dir.join(asset_path))
      elsif vite_manifest.send(:lookup, asset_path)&.dig('file').blank?
        return "/vendor/gems/data-cycle-core/app/assets/#{asset_path}"
      end

      asset_path
    end
  end
end
