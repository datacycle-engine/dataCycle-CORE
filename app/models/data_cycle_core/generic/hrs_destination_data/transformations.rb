# frozen_string_literal: true

module DataCycleCore
  module Generic
    module HrsDestinationData
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.hrs_to_event(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('event', 'name') })
          .>> t(:add_field, 'description', ->(s) { s.dig('event', 'text') })
          .>> t(:add_field, 'external_key', ->(s) { 'HRS DD ' + s.dig('event', 'id').to_s })
          .>> t(:add_links, 'hrs_dd_categories', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('event', 'category', 'id')]&.compact&.flatten&.map { |item| "HRS DD - Classification: #{s.dig('event', 'classification', 'id')}_#{item}" }&.flatten || [] })
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('event', 'venue', 'id')]&.compact&.flatten&.map { |item| "HRS DD - Venue: #{item}" } })
          .>> t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('event', 'contact', 'id')]&.compact&.flatten&.map { |item| "HRS DD - Organizer: #{item}" } })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('event', 'image', 'id')]&.compact&.flatten&.map { |item| "HRS DD - Image: #{item}" } })
          .>> t(:add_field, 'event_period', ->(s) { parse_event_period(s.dig('dates'), s.dig('event')) })
          .>> t(:add_field, 'sub_event', ->(s) { parse_sub_event(s.dig('dates'), s.dig('event')) })
          .>> t(:event_schedule, ->(s) { s.dig('sub_event') })
          .>> t(:strip_all)
        end
        # .>> t(:add_field, 'valid_from', ->(s) { s.dig('event', 'firstDate') })
        # .>> t(:add_field, 'valid_until', ->(s) { s.dig('event', 'lastDate') })
        # .>> t(:nest, 'validity_period', ['valid_from', 'valid_until'])

        def self.hrs_to_image
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'HRS DD - Image: ' + s.dig('id').to_s })
          .>> t(:add_field, 'alternative_headline', ->(s) { s.dig('altLabel') })
          .>> t(:add_field, 'content_url', ->(s) { ['http:', s.dig('thumbnails', 't0', 'url')].join if s.dig('thumbnails', 't0', 'url').present? })
          .>> t(:add_field, 'thumbnail_url', ->(s) { ['http:', s.dig('thumbnails', 't2', 'url')].join if s.dig('thumbnails', 't2', 'url').present? })
          .>> t(:add_field, 'width', ->(s) { s.dig('thumbnails', 't0', 'width') })
          .>> t(:add_field, 'height', ->(s) { s.dig('thumbnails', 't0', 'height') })
          .>> t(:add_field, 'license', ->(s) { s.dig('copyright') })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.hrs_to_place
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'HRS DD - Venue: ' + s.dig('id').to_s })
          .>> t(:rename_keys, { 'city' => 'address_locality', 'country' => 'address_country', 'street' => 'street_address', 'zip' => 'postal_code' })
          .>> t(:nest, 'address', ['address_locality', 'address_country', 'street_address', 'postal_code'])
          .>> t(:rename_keys, { 'website' => 'url', 'mail' => 'email' })
          .>> t(:nest, 'contact_info', ['telephone', 'url', 'email'])
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.hrs_to_organization
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'HRS DD - Organizer: ' + s.dig('id').to_s })
          .>> t(:rename_keys, { 'city' => 'address_locality', 'country' => 'address_country', 'street' => 'street_address', 'zip' => 'postal_code' })
          .>> t(:nest, 'address', ['address_locality', 'address_country', 'street_address', 'postal_code'])
          .>> t(:rename_keys, { 'website' => 'url', 'mail' => 'email' })
          .>> t(:nest, 'contact_info', ['telephone', 'url', 'email'])
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.parse_event_period(dates, event_data)
          return nil if dates.blank?
          date = dates.map(&:in_time_zone).min
          end_date = dates.map(&:in_time_zone).max
          end_date += event_data.dig('duration').to_f.hours if event_data.dig('duration').present?
          {
            'start_date' => date,
            'end_date' => end_date
          }
        end

        def self.parse_sub_event(dates, event_data)
          return nil if dates.size < 2
          dates.map do |date_string|
            date = date_string.in_time_zone
            end_date = date
            end_date += event_data.dig('duration').to_f.hours if event_data.dig('duration').present?
            {
              'event_period' => {
                'start_date' => date,
                'end_date' => end_date
              }
            }
          end
        end
      end
    end
  end
end
