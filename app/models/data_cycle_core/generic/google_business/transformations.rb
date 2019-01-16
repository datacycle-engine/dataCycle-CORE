# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GoogleBusiness
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::GoogleBusiness::TransformationFunctions[*args]
        end

        def self.location_to_place(external_source_id)
          t(:stringify_keys)
          .>> t(:rename_keys, 'name' => 'external_key')
          .>> t(:rename_keys, 'locationName' => 'name')
          .>> t(:add_field, 'latitude', ->(s) { s['latlng'].try(:[], 'latitude').try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s['latlng'].try(:[], 'longitude').try(:to_f) })
          .>> t(:location)
          .>> t(:rename_keys, 'primaryPhone' => 'telephone', 'websiteUrl' => 'url')
          .>> t(:nest, 'contact_info', ['telephone', 'url'])
          .>> t(:add_field, 'street_address', ->(s) { s.dig('address', 'addressLines').join('; ') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('address', 'locality') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('address', 'postalCode') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('address', 'regionCode') })
          .>> t(:nest, 'address', ['street_address', 'address_locality', 'address_country', 'postal_code'])
          .>> t(:add_links, 'google_business_primary_category', DataCycleCore::Classification, external_source_id,
                ->(s) { s.dig('primaryCategory', 'categoryId') || [] })
          .>> t(:add_links, 'google_business_additional_categories', DataCycleCore::Classification, external_source_id,
                ->(s) { (s['additionalCategories'] || []).map { |c| c['categoryId'] } })
          .>> t(:reject_all_keys, except: ['external_key', 'name', 'location', 'address', 'contact_info',
                                           'google_business_primary_category', 'google_business_additional_categories'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
