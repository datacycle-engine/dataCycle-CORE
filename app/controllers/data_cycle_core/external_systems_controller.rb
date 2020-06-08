# frozen_string_literal: true

module DataCycleCore
  class ExternalSystemsController < ApplicationController
    def authorize
      @external_source = ExternalSystem.find(params[:id])

      endpoints = @external_source.config['download_config'].values.map { |v| v['endpoint'] }

      return head :forbidden unless endpoints.include?('DataCycleCore::Generic::GoogleBusiness::Endpoint')

      params = URI.encode_www_form(
        scope: 'https://www.googleapis.com/auth/plus.business.manage',
        access_type: 'offline',
        include_granted_scopes: true,
        redirect_uri: callback_external_source_url(@external_source),
        response_type: 'code',
        client_id: @external_source.credentials&.dig('client_id')
      )

      redirect_to "https://accounts.google.com/o/oauth2/v2/auth?#{params}"
    end

    def callback
      @external_source = ExternalSystem.find(params[:id])

      endpoints = @external_source.config['download_config'].values.map { |v| v['endpoint'] }

      return head :forbidden unless endpoints.include?('DataCycleCore::Generic::GoogleBusiness::Endpoint')

      response = Faraday.new(url: 'https://www.googleapis.com/oauth2/v3/token').post do |req|
        req.params['code'] = params['code']
        req.params['client_id'] = @external_source.credentials&.dig('client_id')
        req.params['client_secret'] = @external_source.credentials&.dig('client_secret')
        req.params['redirect_uri'] = callback_external_source_url(@external_source)
        req.params['grant_type'] = 'authorization_code'
      end

      @data = JSON.parse(response.body)
    end
  end
end
