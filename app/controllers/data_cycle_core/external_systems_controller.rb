# frozen_string_literal: true

module DataCycleCore
  class ExternalSystemsController < ApplicationController
    def authorize
      @external_source = ExternalSystem.find(params[:id])

      endpoints = @external_source.config['download_config'].values.pluck('endpoint')

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

      endpoints = @external_source.config['download_config'].values.pluck('endpoint')

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

    def create
      authorize! :create, DataCycleCore::ExternalSystem

      partial = helpers.external_system_template_paths[external_system_params[:identifier]]

      raise ActiveRecord::RecordNotFound if partial.nil?

      data = YAML.safe_load(
        ERB.new(File.read(partial)).result_with_hash(params: params.require(:external_system).to_unsafe_hash),
        permitted_classes: [Symbol]
      )

      redirect_back(fallback_location: root_path, alert: I18n.t('controllers.error.external_system_already_exists', locale: helpers.active_ui_locale)) && return if DataCycleCore::ExternalSystem.exists?(identifier: data['identifier']) || DataCycleCore::ExternalSystem.exists?(name: data['name'])

      error = DataCycleCore::MasterData::ImportExternalSystems.validate(data.deep_symbolize_keys)
      redirect_back(fallback_location: root_path, alert: error) && return if error.present?

      data['identifier'] ||= data['name']
      external_system = DataCycleCore::ExternalSystem.new(identifier: data['identifier'], name: data['name'])

      external_system.attributes = data.slice('name', 'identifier', 'credentials', 'config', 'default_options', 'deactivated').reverse_merge!({ 'name' => nil, 'identifier' => nil, 'credentials' => nil, 'config' => nil, 'default_options' => nil, 'deactivated' => nil })
      if external_system.save
        flash[:success] = I18n.t('controllers.success.external_system_created', locale: helpers.active_ui_locale)
      else
        flash[:error] = I18n.with_locale(helpers.active_ui_locale) { external_system.errors.messages.transform_keys { |k| external_system.class.human_attribute_name(k, locale: helpers.active_ui_locale) } }
      end

      redirect_back(fallback_location: root_path)
    end

    def render_new_form
      authorize! :create, DataCycleCore::ExternalSystem

      identifier = external_system_params[:identifier]

      render(json: { html: '' }) && return if identifier.blank?

      partial = "external_systems/form_templates/#{identifier}"
      partial = 'data_cycle_core/external_systems/form_templates/default' unless lookup_context.exists?(partial, [], true, [], formats: [:html])

      render json: { html: render_to_string(formats: [:html], layout: false, partial:) }
    end

    private

    def external_system_params
      params.require(:external_system).permit(:identifier)
    end
  end
end
