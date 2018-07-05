# frozen_string_literal: true

module DataCycleCore
  module Generic
    module VTicket
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.vticket_location_to_content_location
          t(:stringify_keys)
          .>> t(:underscore_keys)
          .>> t(:rename_keys, 'id' => 'external_key')
          .>> t(:unwrap, 'address')
          .>> t(:rename_keys, 'country' => 'address_country', 'city' => 'address_locality')
          .>> t(:add_field, 'street_address', ->(s) { "#{s.dig('street')} #{s.dig('street_number')}" })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_country', 'address_locality'])
          .>> t(:reject_keys, ['street_number', 'street', 'string', 'id', 'slug', 'meta'])
          .>> t(:add_field, 'latitude', ->(s) { s.dig('lat')&.try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('lng')&.try(:to_f) })
          .>> t(:location)
          .>> t(:compact)
          .>> t(:strip_all)
        end

        def self.vticket_to_image
          t(:stringify_keys)
          .>> t(:rename_keys, { 'name' => 'headline', 'original' => 'content_url', 'thumbnail' => 'thumbnail_url' })
          .>> t(:reject_keys, ['large', 'middle', 'small'])
          .>> t(:add_field, 'external_key', ->(s) { s.dig('content_url')&.split('/')&.fetch(-3) if s.dig('content_url')&.split('/')&.count == 7 })
          .>> t(:strip_all)
        end

        def self.vticket_to_event(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:reject_keys, ['slug', 'promoter'])
          .>> t(:underscore_keys)
          .>> t(:rename_keys, { 'id' => 'external_key', 'location' => 'event_location', 'categories' => 'v_ticket_categories', 'tags' => 'v_ticket_tags' })
          .>> t(:add_field, 'name', ->(s) { s.dig('title') + (s.dig('subtitle').present? ? " - #{s.dig('subtitle')}" : '') })
          .>> t(:add_field, 'url', ->(s) { s&.dig('meta', 'permalink') })
          .>> t(:add_field, 'same_as', ->(s) { s&.try(:[], 'links')&.first&.try(:[], 'url') })
          .>> t(:add_links, 'image', DataCycleCore::CreativeWork, external_source_id, ->(s) { s&.dig('images')&.map { |item| item.dig('original')&.split('/')&.fetch(-3) if item.dig('original')&.split('/')&.count == 7 } || [] })
          .>> t(:add_link, 'location', DataCycleCore::Place, external_source_id, ->(s) { s.dig('event_location', 'id') })
          .>> t(:tags_to_ids, 'v_ticket_categories', external_source_id, 'VTicket - Categories - ')
          .>> t(:tags_to_ids, 'v_ticket_tags', external_source_id, 'VTicket - Tags - ')
          .>> t(:reject_keys, ['title', 'event_location', 'sub_event', 'end', 'start'])
          .>> t(:strip_all)
        end

        def self.vticket_subevent_to_subevent
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:reject_keys, ['slug', 'promoter', 'categories', 'tags', 'description'])
          .>> t(:underscore_keys)
          .>> t(:rename_keys, { 'id' => 'external_key', 'start' => 'start_date', 'end' => 'end_date', 'location' => 'event_location' })
          .>> t(:add_field, 'url', ->(s) { s&.dig('meta', 'permalink') })
          .>> t(:nest, 'event_period', ['start_date', 'end_date'])
          .>> t(:reject_keys, ['title', 'location', 'sub_event', 'end', 'start'])
          .>> t(:strip_all)
        end

        def self.add_place_to_subevent(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:add_link, 'location', DataCycleCore::Place, external_source_id, ->(s) { s.dig('event_location', 'id') })
          .>> t(:reject_keys, ['event_location'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
