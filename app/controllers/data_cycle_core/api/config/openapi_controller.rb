# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      # Serves the per-instance OpenAPI 3.1 document (schemas + paths) under GET /api/config/openapi.
      class OpenapiController < ::DataCycleCore::Api::Config::ApiBaseController
        include DataCycleCore::AvailableLocaleResolver

        before_action :prepare_url_parameters

        # Renders the generated OpenAPI 3.1 document as JSON for the requested locale.
        def index
          render json: DataCycleCore::OpenApi::DocumentBuilder.new(locale:).call
        end

        # Adds :language to the base API parameter allowlist.
        def permitted_parameter_keys
          super + [:language]
        end

        private

        # Restricts the requested :language to a locale the document is translated into,
        # falling back to the default (no user fallback — API responses stay stable per
        # parameter). Without the narrowing, ?language=fr on a host that configures fr
        # answered with "Translation missing: fr.open_api.…" strings in the document body.
        def locale
          resolve_available_locale(
            permitted_params[:language],
            fallback: nil,
            available: DataCycleCore::OpenApi::Translations.available_locales
          )
        end
      end
    end
  end
end
