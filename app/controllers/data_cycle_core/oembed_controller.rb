# frozen_string_literal: true

module DataCycleCore
  class OembedController < ApplicationController
    def fetch
      permitted_params[:locale] || 'de'
      permitted_params[:format] || :json

      maxwidth = permitted_params[:maxwidth]
      maxheight = permitted_params[:maxheight]

      url = permitted_params[:url]

      oembed = DataCycleCore::MasterData::Validators::Oembed.valid_oembed_data?(url, maxwidth, maxheight)

      if oembed[:error].present? && (oembed[:error][:error].present? || oembed[:error][:warning].present?)
        errors = oembed.dig(:error, :error)&.values&.flatten || []
        warnings = oembed.dig(:error, :warning)&.values&.flatten || []

        localized_errors = []

        (errors + warnings).each do |error|
          localized = DataCycleCore::LocalizationService.translate_and_substitute(error.to_h, helpers.active_ui_locale)
          localized_errors << localized
        end

        render json: { errors: localized_errors.uniq }.to_json, status: :bad_request
      else
        oembed_uri = URI(oembed[:oembed_url])
        response = Rails.cache.fetch(oembed[:oembed_url], expires_in: 15.minutes) do
          Net::HTTP.get_response(oembed_uri)
        end

        if response.code == '200'
          render json: JSON.parse(response.body), status: :ok
        else
          render json: response.body, status: response.code
        end

      end
    end

    private

    def permitted_params
      @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
    end

    def permitted_parameter_keys
      [:url, :locale, :format, :maxwidth, :maxheight]
    end

    def set_default_response_format
      request.format = :json
    end

    def oembed_params(template_name, params_hash = nil)
      params_hash = params.fetch(:thing) { { } } if params_hash.blank?
      params_hash.permit(:url, DataCycleCore::DataHashService.get_object_params(template_name, params_hash))
    end
  end
end
