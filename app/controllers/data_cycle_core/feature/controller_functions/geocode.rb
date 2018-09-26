# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Geocode
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.append do
            unless has_named_route?(:geocode_address_creative_work)
              DataCycleCore.content_tables.each do |table|
                get "/#{table}/geocode_address", action: :geocode_address, controller: table, as: "geocode_address_#{table.singularize}"
              end
            end
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
