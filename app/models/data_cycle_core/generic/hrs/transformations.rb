# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Hrs
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.hrs_to_unterkunft(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'latitude', ->(s) { s.dig('o_gps', 'longitude', 'text')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('o_gps', 'longitude', 'text')&.to_f })
          .>> t(:location)
          .>> t(:add_field, 'name', ->(s) { s.dig('o_bezeichnung', 'text') })
          .>> t(:add_field, 'url', ->(s) { s.dig('o_url', 'text') })
          .>> t(:nest, 'contact_info', ['url'])
          .>> t(:add_field, 'street_address', ->(s) { s.dig('o_strasse', 'text') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('o_plz', 'text') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('o_ort', 'text') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('o_land', 'iso3166_alpha2') })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:unwrap, 'attributes', ['position-latitude', 'position-longitude', 'tags', 'description', 'name'])
          .>> t(:tags_to_ids, 'tags', external_source_id, 'Xamoom - tag - ')
          .>> t(:add_field, 'image', ->(s) { s.dig('attributes', 'image').present? ? [DataCycleCore::Thing.find_by(external_key: "Xamoom - #{s['id']} - image")&.id] : nil })
          .>> t(:add_field, 'external_key', ->(s) { "HRS - #{s.dig('o_id', 'text')}" })
          .>> t(:reject_keys, ['o_id', 'o_gps', 'o_bezeichnung', 'o_url', 'o_ort', 'o_strasse', 'o_plz', 'o_ort', 'o_land'])
          .>> t(:strip_all)
        end

        def self.hrs_to_image
          t(:stringify_keys)
          .>> t(:unwrap, 'attributes', ['name', 'image'])
          .>> t(:rename_keys, { 'image' => 'thumbnail_url' })
          .>> t(:add_field, 'external_key', ->(s) { "HRS - #{s['id']} - image" })
          .>> t(:reject_keys, ['attributes', 'id'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
