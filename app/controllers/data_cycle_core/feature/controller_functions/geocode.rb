# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Geocode
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            get '/things/geocode_address', action: :geocode_address, controller: 'things', as: 'geocode_address_thing' unless has_named_route?(:geocode_address_thing)
          end
          Rails.application.reload_routes!
        end

        def geocode_address
          external_source = DataCycleCore::ExternalSource.find_by(name: DataCycleCore.features.dig(:geocode, :external_source))

          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'Adresse', locale: DataCycleCore.ui_language) }.to_json, content_type: 'application/json') && return if external_source.blank? || address_params.blank? || address_params.values.all?(&:blank?)

          endpoint = DataCycleCore.features.dig(:geocode, :endpoint).constantize.new(external_source.credentials.symbolize_keys)
          geocoded_data = endpoint.geocode(address_params.to_h)

          render plain: [geocoded_data.presence&.x, geocoded_data.presence&.y].compact.to_json, content_type: 'application/json'
        end

        private

        def address_params
          params.permit(:street_address, :postal_code, :address_locality, :address_country)
        end
      end
    end
  end
end
