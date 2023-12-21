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

        def target_key(content = nil)
          configuration(content).dig('target_key')
        end

        def target_key?(key, content = nil)
          return false if target_key(content).blank?

          key.attribute_name_from_key == target_key(content)
        end

        def reverse_geocode_enabled?
          configuration.dig('reverse_geocode', 'enabled')
        end

        def reverse_geocode_source(content = nil)
          Array.wrap(configuration(content).dig('reverse_geocode', 'attribute_keys')).first
        end

        def reverse_geocode_target_key(content = nil)
          configuration(content).dig('reverse_geocode', 'target_key')
        end

        def reverse_geocode_target_key?(key, content = nil)
          return false if reverse_geocode_target_key(content).blank?

          key.attribute_name_from_key == reverse_geocode_target_key(content)
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

          Rails.cache.fetch(geocode_cache_key(address_hash), expires_in: 7.days) do
            endpoint.geocode(address_hash.to_h, locale)
          end
        end

        def reverse_geocode(geo, locale = I18n.locale)
          return {} if endpoint.blank? || !endpoint.respond_to?(:reverse_geocode) || geo.blank?

          geo = DataCycleCore::MasterData::DataConverter.string_to_geographic(geo)

          Rails.cache.fetch(reverse_geocode_cache_key(geo), expires_in: 7.days) do
            endpoint.reverse_geocode(geo, locale)
          end
        end

        def geodata_to_attributes(geodata)
          return {} if geodata.blank?

          { location: geodata.to_s, longitude: geodata.try(:x)&.round(5), latitude: geodata.try(:y)&.round(5) }
        end

        def geocode_cache_key(data)
          Digest::SHA1.hexdigest(data.sort.to_h.transform_values(&:downcase).to_json)
        end

        def reverse_geocode_cache_key(geo)
          Digest::SHA1.hexdigest(geo.to_s)
        end
      end
    end
  end
end
