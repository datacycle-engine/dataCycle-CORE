# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GoogleBusiness
      module Transformations
        DAY_OF_WEEK_TRANSLATIONS = {
          'MONDAY' => 'Montag',
          'TUESDAY' => 'Dienstag',
          'WEDNESDAY' => 'Mittwoch',
          'THURSDAY' => 'Donnerstag',
          'FRIDAY' => 'Freitag',
          'SATURDAY' => 'Samstag',
          'SUNDAY' => 'Sonntag'
        }.freeze

        def self.t(*args)
          DataCycleCore::Generic::GoogleBusiness::TransformationFunctions[*args]
        end

        def self.location_to_place(external_source_id)
          t(:stringify_keys)
          .>> t(:unwrap, 'locationKey', ['placeId'])
          .>> t(:rename_keys, 'placeId' => 'external_key')
          .>> t(:rename_keys, 'locationName' => 'name')
          .>> t(:add_field, 'latitude', ->(s) { s['latlng'].try(:[], 'latitude').try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s['latlng'].try(:[], 'longitude').try(:to_f) })
          .>> t(:location)
          .>> t(:rename_keys, 'primaryPhone' => 'telephone', 'websiteUrl' => 'url')
          .>> t(:nest, 'contact_info', ['telephone', 'url'])
          .>> t(:add_field, 'street_address', ->(s) { s.dig('address', 'addressLines')&.join('; ') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('address', 'locality') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('address', 'postalCode') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('address', 'regionCode') })
          .>> t(:nest, 'address', ['street_address', 'address_locality', 'address_country', 'postal_code'])
          .>> t(:add_field, 'opening_hours_specification',
                ->(s) { convert_opening_hours(s['regularHours']) })
          .>> t(:add_links, 'google_business_primary_category', DataCycleCore::Classification, external_source_id,
                ->(s) { s.dig('primaryCategory', 'categoryId') || [] })
          .>> t(:add_links, 'google_business_additional_categories', DataCycleCore::Classification, external_source_id,
                ->(s) { (s['additionalCategories'] || []).map { |c| c['categoryId'] } })
          .>> t(:reject_all_keys, except: ['external_key', 'name', 'location', 'address', 'contact_info',
                                           'opening_hours_specification',
                                           'google_business_primary_category', 'google_business_additional_categories'])
          .>> t(:strip_all)
        end

        def self.convert_opening_hours(_raw_data)
          raise 'wrong opening_hours_specification type, transformation has to be updated if this importer is used again'

          # raw_data = { 'periods' => [] } if raw_data.nil?

          # raw_data['periods'].map { |period|
          #   raise 'Converting opening hours does not support different open and close day' if period['openDay'] != period['closeDay']

          #   {
          #     opens: period['openTime'],
          #     closes: period['closeTime'],
          #     day_of_week: [load_day_of_week(period['openDay'])]
          #   }
          # }.group_by { |opening_hours|
          #   "#{opening_hours[:opens]} - #{opening_hours[:closes]}"
          # }.map { |_, opening_hours| # rubocop:disable Style/BlockDelimiters
          #   opening_hours.first.merge(day_of_week: opening_hours.map { |h| h[:day_of_week] }.flatten)
          # }
        end

        def self.load_day_of_week(day)
          DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Wochentage', DAY_OF_WEEK_TRANSLATIONS[day])
        end
      end
    end
  end
end
