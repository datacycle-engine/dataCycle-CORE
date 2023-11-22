# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Geocode < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::Geocode
        end

        def address_source(content = nil)
          attribute_keys(content).first
        end

        def allowed_attribute_keys(content = nil)
          attribute_keys(content) || []
        end

        def external_source
          @external_source ||= DataCycleCore::ExternalSystem.find_by(name: configuration.dig(:external_source))
        end

        def endpoint
          return if external_source.blank?

          @endpoint ||= configuration.dig(:endpoint).constantize.new(**external_source.credentials.symbolize_keys)
        end

        def geocode_address(address_hash, locale = I18n.locale)
          return {} if endpoint.blank? || address_hash.blank? || address_hash.values.all?(&:blank?)

          endpoint.geocode(address_hash.to_h, locale)
        end

        def reverse_geocode(geo, locale = I18n.locale)
          return {} if endpoint.blank? || !endpoint.respond_to?(:reverse_geocode) || geo.blank?

          geo = DataCycleCore::MasterData::DataConverter.string_to_geographic(geo)

          endpoint.reverse_geocode(geo, locale)
        end

        def geodata_to_attributes(geodata)
          return {} if geodata.blank?

          { location: geodata.to_s, longitude: geodata.try(:x)&.round(5), latitude: geodata.try(:y)&.round(5) }
        end
      end
    end
  end
end
