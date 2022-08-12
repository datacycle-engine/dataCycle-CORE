# frozen_string_literal: true

module DataCycleCore
  module Mvt
    module V1
      class MvtBaseController < ::DataCycleCore::Api::V4::ApiBaseController
        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def prepare_url_parameters
          @language = parse_language(permitted_params.dig(:language)).presence || Array(I18n.available_locales.first.to_s)
          @api_version = 1
        end

        def log_activity
        end
      end
    end
  end
end
