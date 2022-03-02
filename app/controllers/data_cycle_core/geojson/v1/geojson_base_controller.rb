# frozen_string_literal: true

module DataCycleCore
  module Geojson
    module V1
      class GeojsonBaseController < ::DataCycleCore::Api::V4::ApiBaseController
        def prepare_url_parameters
          @language = parse_language(permitted_params.dig(:language)).presence || Array(I18n.available_locales.first.to_s)
          @api_version = 1
        end
      end
    end
  end
end
