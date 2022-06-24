# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gem2go
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Gem2go::TransformationFunctions[*args]
        end

        def self.to_event(external_source_id)
          t(:add_field, 'external_key', ->(s) { "GEM2GO - Event - #{s.dig('id', 'text')}" })
          .>> t(:add_schedule, external_source_id, ->(s) { s.dig('external_key') })
          .>> t(:add_field, 'name', ->(s) { s.dig('title', 'text') })
          .>> t(:add_field, 'description', ->(s) { s.dig('text', 'text') })
          .>> t(:add_info, ['description'], external_source_id)
          .>> t(:add_field, 'date_created', ->(s) { s.dig('created', 'text') })
          .>> t(:add_links, 'gem2go_category', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('category')).map { |i| "GEM2GO - Event - Kategorie - #{i.dig('id')}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('gem2go_category') })
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap("GEM2GO - EventLocation - #{s.dig('id', 'text')}") })
          .>> t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap("GEM2GO - Organizer - #{s.dig('id', 'text')}") })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s&.dig('image')).map { |i| "GEM2GO - Image - #{Digest::MD5.hexdigest(i.dig('url', 'text'))}" } })
          .>> t(:reject_keys, ['id'])
        end

        def self.to_content_location
          t(:add_field, 'external_key', ->(s) { "GEM2GO - EventLocation - #{s.dig('id', 'text')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('venue', 'text') || "Veranstaltungsort: #{s.dig('title', 'text')}" })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('address', 'lat', 'text')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('address', 'long', 'text')&.to_f })
          .>> t(:location)
          .>> t(:add_field, 'street_address', ->(s) { [s.dig('address', 'street', 'text'), s.dig('address', 'houseno', 'text')].map(&:presence).compact.join(' ').presence })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('address', 'postcode', 'text') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('address', 'city', 'text') })
          .>> t(:reject_keys, ['address', 'venue'])
          .>> t(:add_field, 'address_country', ->(_) { 'Österreich' })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:reject_keys, ['id'])
        end

        def self.to_organizer
          t(:add_field, 'external_key', ->(s) { "GEM2GO - Organizer - #{s.dig('id', 'text')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('contact', 'name', 'text') || "Veranstalter: #{s.dig('title', 'text')}" })
          .>> t(:add_field, 'street_address', ->(s) { [s.dig('contact', 'address', 'street', 'text'), s.dig('contact', 'address', 'houseno', 'text')].map(&:presence).compact.join(' ').presence })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('contact', 'address', 'postcode', 'text') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('contact', 'address', 'city', 'text') })
          .>> t(:add_field, 'address_country', ->(_) { 'Österreich' })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'email', ->(s) { s.dig('contact', 'email', 'text')&.strip })
          .>> t(:add_field, 'url', ->(s) { s.dig('contact', 'link', 'text')&.strip })
          .>> t(:nest, 'contact_info', ['email', 'url'])
          .>> t(:reject_keys, ['id', 'contact'])
        end

        def self.to_image
          t(:add_field, 'external_key', ->(s) { "GEM2GO - Image - #{Digest::MD5.hexdigest(s.dig('url', 'text'))}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('alttext', 'text').presence || '__NO_NAME__' })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('url', 'text')&.strip })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('url', 'text')&.strip })
          .>> t(:add_field, 'url', ->(s) { s.dig('url', 'text')&.strip })
          .>> t(:add_field, 'copyright_notice_override', ->(s) { s.dig('copyright', 'text') })
          .>> t(:add_field, 'source', ->(s) { s.dig('source', 'text') })
          .>> t(:reject_keys, ['alttext'])
        end
      end
    end
  end
end
