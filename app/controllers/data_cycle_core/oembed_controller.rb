# frozen_string_literal: true

module DataCycleCore
  class OembedController < ApplicationController
    def fetch
      # Default parameters
      permitted_params[:locale] || 'de'
      permitted_params[:format] || :json
      maxwidth = permitted_params[:maxwidth]
      maxheight = permitted_params[:maxheight]
      url = permitted_params[:url]

      response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'

      oembed = DataCycleCore::MasterData::Validators::Oembed.valid_oembed_data?(url, maxwidth, maxheight)

      Rails.logger.debug { "OEMBED DATA: #{oembed.to_json}" }

      if oembed[:error].present? && (oembed[:error][:error].present? || oembed[:error][:warning].present?) && oembed[:success] != true
        errors = oembed.dig(:error, :error)&.values&.flatten || []
        warnings = oembed.dig(:error, :warning)&.values&.flatten || []

        localized_errors = errors + warnings
        localized_errors.map! do |error|
          DataCycleCore::LocalizationService.translate_and_substitute(error.to_h, helpers.active_ui_locale)
        end

        render json: { errors: localized_errors.uniq }, status: :bad_request
      else
        cache_key = "oembed/#{Digest::MD5.hexdigest(oembed[:oembed_url])}/#{maxwidth}/#{maxheight}"
        oembed_uri = URI(oembed[:oembed_url])

        response = Rails.cache.fetch(cache_key, expires_in: 15.minutes, skip_nil: true) do
          res = Net::HTTP.get_response(oembed_uri)
          res.is_a?(Net::HTTPSuccess) ? res.body : nil
        end

        if response
          render json: JSON.parse(response), status: :ok
        else
          render json: { errors: ['Failed to fetch oEmbed data'] }, status: :bad_request
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
  end
end
