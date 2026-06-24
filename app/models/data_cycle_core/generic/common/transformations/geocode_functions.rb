# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module GeocodeFunctions
          def self.geocode(data, *)
            data['universal_classifications'] = [] unless data&.key?('universal_classifications')
            return data unless DataCycleCore::Feature['Geocode']&.enabled? && data&.key?('address') && data.dig('address', 'postal_code').present? && data.dig('address', 'street_address').present? && data.dig('address', 'address_locality').present? && data['location'].blank?

            location = DataCycleCore::Feature['Geocode'].geocode_address(data['address'])

            if location.is_a?(RGeo::Feature::Point) && location.present?
              data['location'] = location
              data['longitude'] = location.x
              data['latitude'] = location.y
              data['universal_classifications'] = (data['universal_classifications'] || []) +
                                                  DataCycleCore::Concept.for_tree('Geocoding')
                                                    .with_internal_name('geocoded')
                                                    .pluck(:classification_id)
            else
              data['universal_classifications'] = (data['universal_classifications'] || []) -
                                                  DataCycleCore::Concept.for_tree('Geocoding')
                                                    .with_internal_name('geocoded')
                                                    .pluck(:classification_id)
            end

            data
          end

          def self.reverse_geocode(data, *)
            data['universal_classifications'] = [] unless data&.key?('universal_classifications')
            return data unless DataCycleCore::Feature['Geocode'].reverse_geocode_enabled? && data&.key?('location') && data['address']&.compact_blank.blank?

            address_hash = DataCycleCore::Feature['Geocode'].reverse_geocode(data['location'])

            if address_hash.is_a?(DataCycleCore::OpenStructHash) && address_hash.present?
              data['address'] = address_hash.to_h
              data['universal_classifications'] = (data['universal_classifications'] || []) +
                                                  DataCycleCore::Concept.for_tree('Geocoding')
                                                    .with_internal_name('reverse_geocoded')
                                                    .pluck(:classification_id)
            else
              data['universal_classifications'] = (data['universal_classifications'] || []) -
                                                  DataCycleCore::Concept.for_tree('Geocoding')
                                                    .with_internal_name('reverse_geocoded')
                                                    .pluck(:classification_id)
            end

            data
          end
        end
      end
    end
  end
end
