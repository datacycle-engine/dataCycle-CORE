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
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'Adresse', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if address_params.blank? || address_params.values.all?(&:blank?)

          geocoded_data = DataCycleCore::Feature::Geocode.geocode_address(address_params.to_h, locale_params[:locale])

          if geocoded_data.try(:error).present?
            render(
              plain: {
                error: DataCycleCore::LocalizationService.translate_and_substitute(geocoded_data.error, helpers.active_ui_locale)
              }.to_json,
              content_type: 'application/json'
            ) && return
          end

          render plain: [geocoded_data.presence&.x, geocoded_data.presence&.y].compact.to_json, content_type: 'application/json'
        end

        private

        def address_params
          params.permit(:street_address, :postal_code, :address_locality, :address_country)
        end

        def locale_params
          params.permit(:locale)
        end
      end
    end
  end
end
