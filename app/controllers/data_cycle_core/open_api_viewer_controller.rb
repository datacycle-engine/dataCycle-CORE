# frozen_string_literal: true

module DataCycleCore
  # Hosts the interactive Swagger UI page for the per-instance OpenAPI document
  # (rendered from GET /api/config/openapi). Open to every logged-in user: it describes
  # the API they are already entitled to call, so it carries no authorization of its own
  # -- the `authenticate` block in config/routes.rb is the only gate, matching the spec
  # endpoint it loads from.
  class OpenApiViewerController < ApplicationController
    include DataCycleCore::AvailableLocaleResolver

    layout 'data_cycle_core/open_api_viewer'

    # Renders the Swagger UI container; the spec URL and available locales are
    # handed to the view so the page can load the document and offer a switcher.
    def show
      # Never cache the shell HTML: it references content-hashed Vite assets, so a
      # cached page would keep loading stale JS/CSS after a rebuild (the viewer
      # then renders an outdated spec/layout). Assets stay long-cached by hash.
      response.headers['Cache-Control'] = 'no-store'

      @spec_path = api_config_openapi_path(format: :json)
      # Only the locales the document is actually translated into — the switcher used to
      # publish every configured locale, so a host with fr/it configured offered tabs that
      # rendered "Translation missing: fr.open_api.info.description" as the description.
      @available_locales = DataCycleCore::OpenApi::Translations.available_locales
      # mirrors the openapi endpoint's allowlist, falling back to the user's UI
      # locale (active_ui_locale is a view helper, not available here)
      @spec_language = resolve_available_locale(params[:language], available: @available_locales)
    end
  end
end
