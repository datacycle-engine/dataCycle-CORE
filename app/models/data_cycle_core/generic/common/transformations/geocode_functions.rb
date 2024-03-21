# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module GeocodeFunctions
          def self.geocode(data)
            return data unless Feature::Geocode.enabled? && data&.key?('address') && data.dig('address', 'postal_code').present? && data.dig('address', 'street_address').present? && data.dig('address', 'address_locality').present? && data['location'].blank?

            location = Feature::Geocode.geocode_address(data['address'])

            if location.is_a?(RGeo::Feature::Point) && location.present?
              data['location'] = location
              data['longitude'] = location.x
              data['latitude'] = location.y
              data['universal_classifications'] = (data['universal_classifications'] || []) + DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Geocoding', 'geocoded')
            end

            data
          end

          def self.reverse_geocode(data)
            return data unless Feature::Geocode.reverse_geocode_enabled? && data&.key?('location') && data['address']&.compact_blank.blank?

            address_hash = Feature::Geocode.reverse_geocode(data['location'])

            if address_hash.is_a?(DataCycleCore::OpenStructHash) && address_hash.present?
              data['address'] = address_hash.to_h
              data['universal_classifications'] = (data['universal_classifications'] || []) + DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Geocoding', 'reverse_geocoded')
            end

            data
          end
        end
      end
    end
  end
end
