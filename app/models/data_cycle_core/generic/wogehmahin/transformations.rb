# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wogehmahin
      module Transformations
        DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].freeze

        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_food_establishment(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('betriebsname') })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('identifier') })
          .>> t(:reject_keys, ['owners', 'languages', 'Genusslust', 'identifier'])
          .>> t(:add_field, 'street_address', ->(s) { s.dig('address', 'address') })
          .>> t(:unwrap, 'address')
          .>> t(
            :rename_keys,
            {
              'locality' => 'address_locality',
              'postalCode' => 'postal_code',
              'country' => 'address_country'
            }
          )
          .>> t(:add_field, 'latitude', ->(s) { s.dig('location', 'latitude')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('location', 'longitude')&.to_f })
          .>> t(:location)
          .>> t(:map_value, 'postal_code', ->(s) { s == '0' ? nil : s })
          .>> t(:nest, 'address', ['street_address', 'address_locality', 'postal_code', 'address_country'])
          .>> t(
            :rename_keys,
            {
              'telefon' => 'telephone',
              'fax' => 'fax_number',
              'mail' => 'email',
              'web' => 'url'
            }
          )
          .>> t(:nest, 'contact_info', ['telephone', 'fax_number', 'email', 'url'])
          .>> t(:add_field, 'wogehmahin_topics', ->(s) { s.dig('topics')&.map { |item| item.dig('name') } })
          .>> t(:tags_to_ids, 'wogehmahin_topics', external_source_id, 'Wogehmahin - Topic - ')
          .>> t(:add_field, 'wogehmahin_types', ->(s) { s.dig('types')&.map { |item| item.dig('name') } })
          .>> t(:tags_to_ids, 'wogehmahin_types', external_source_id, 'Wogehmahin - Type - ')
          .>> t(:add_field, 'opening_hours_specification', ->(s) { parse_opening_hours(s.dig('OpeningHours')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { s.dig('photos').map { |item| item.dig('identifier') } })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.to_image
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('headline') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('identifier') })
          .>> t(:add_field, 'license', ->(s) { s.dig('copyright').presence })
          .>> t(:strip_all)
        end

        def self.parse_opening_hours(data)
          return if data.blank?

          raise 'wrong opening_hours_specification type, transformation has to be updated if this importer is used again'

          # DataCycleCore::Generic::Common::OpeningHours.new(data, format: :google).to_opening_hours_specifications
        end
      end
    end
  end
end
