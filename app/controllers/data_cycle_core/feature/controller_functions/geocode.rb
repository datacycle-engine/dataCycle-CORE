# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Geocode
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            get '/things/geocode_address', action: :geocode_address, controller: 'things', as: 'geocode_address_thing' unless has_named_route?(:geocode_address_thing)
            get '/things/reverse_geocode_address', action: :reverse_geocode_address, controller: 'things', as: 'reverse_geocode_address_thing' unless has_named_route?(:reverse_geocode_address_thing)
          end

          Rails.application.reload_routes!
        end

        def geocode_address
          render(plain: { error: I18n.t('validation.warnings.no_data', data: 'Adresse', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if address_params.blank? || address_params.values.all?(&:blank?)

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

        def reverse_geocode_address
          render(plain: { error: I18n.t('validation.warnings.no_data', data: 'GPS-Koordinaten', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if location_params.blank? || location_params.dig(:geo, :geometry, :coordinates).blank?

          factory2d = RGeo::Cartesian.factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', has_z_coordinate: false, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 })
          geom = RGeo::GeoJSON.decode(location_params[:geo].to_h, geo_factory: factory2d)

          render(plain: { error: I18n.t('validation.warnings.no_data', data: 'GPS-Koordinaten', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if geom.blank?

          geocoded_data = DataCycleCore::Feature::Geocode.reverse_geocode(geom.geometry.as_text, locale_params[:locale])

          if geocoded_data.try(:error).present?
            render(
              plain: {
                error: DataCycleCore::LocalizationService.translate_and_substitute(geocoded_data.error, helpers.active_ui_locale)
              }.to_json,
              content_type: 'application/json'
            ) && return
          end

          render plain: geocoded_data.to_h.compact.to_json, content_type: 'application/json'
        end

        private

        def address_params
          params.permit(:street_address, :postal_code, :address_locality, :address_country)
        end

        def location_params
          params.permit(geo: [:type, geometry: [:type, coordinates: []]])
        end

        def locale_params
          params.permit(:locale)
        end
      end
    end
  end
end
