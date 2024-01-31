# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module GeocodeFunctions
          def self.geocode(data)
            return data unless Feature::Geocode.enabled? && data&.key?('address') && data['location'].blank?

            location = Feature::Geocode.geocode_address(data['address'])

            data['location'] = location if location.is_a?(RGeo::Feature::Point) && location.present?

            data
          end

          def self.reverse_geocode(data)
            return data unless Feature::Geocode.reverse_geocode_enabled? && data&.key?('location') && data['address'].compact_blank.blank?

            address_hash = Feature::Geocode.reverse_geocode(data['location'])

            data['address'] = address_hash.to_h if address_hash.is_a?(DataCycleCore::OpenStructHash) && address_hash.present?

            data
          end
        end
      end
    end
  end
end
