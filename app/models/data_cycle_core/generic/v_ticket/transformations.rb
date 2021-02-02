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
          .>> t(:map_value, 'external_key', ->(s) { "V-Ticket Location: #{s}" })
          .>> t(:unwrap, 'address')
          .>> t(:rename_keys, 'country' => 'address_country', 'city' => 'address_locality')
          .>> t(:add_field, 'street_address', ->(s) { "#{s.dig('street')} #{s.dig('street_number')}" })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_country', 'address_locality'])
          .>> t(:reject_keys, ['street_number', 'street', 'string', 'id', 'slug', 'meta'])
          .>> t(:add_field, 'latitude', ->(s) { s.dig('lat')&.try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('lng')&.try(:to_f) })
          .>> t(:location)
          .>> t(:strip_all)
        end

        def self.vticket_to_image
          t(:stringify_keys)
          .>> t(:rename_keys, { 'original' => 'content_url', 'middle' => 'thumbnail_url' })
          .>> t(:reject_keys, ['large', 'thumbnail', 'small'])
          .>> t(:add_field, 'external_key', ->(s) { "V-Ticket Image: #{s.dig('content_url')&.split('/')&.fetch(-3)}" if s.dig('content_url')&.split('/')&.count == 7 })
          .>> t(:strip_all)
        end

        def self.vticket_to_event(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:reject_keys, ['slug', 'promoter'])
          .>> t(:underscore_keys)
          .>> t(:rename_keys, { 'id' => 'external_key', 'location' => 'event_location', 'categories' => 'v_ticket_categories', 'tags' => 'v_ticket_tags' })
          .>> t(:map_value, 'external_key', ->(s) { "V-Ticket Event: #{s}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('title') + (s.dig('subtitle').present? ? " - #{s.dig('subtitle')}" : '') }) # .>> t(:add_field, 'url', ->(s) { s&.dig('meta', 'permalink') })
          .>> t(:add_field, 'dc_potential_action', ->(s) { parse_potential_action(s, external_source_id) })
          .>> t(:add_field, 'same_as', ->(s) { s&.try(:[], 'links')&.first&.try(:[], 'url') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('images')&.map { |item| "V-Ticket Image: #{item.dig('original')&.split('/')&.fetch(-3)}" if item.dig('original')&.split('/')&.count == 7 } || [] })
          .>> t(:add_field, 'event_period', ->(s) { event_period(s) })
          .>> t(:reject_keys, ['start', 'end'])
          .>> t(:event_schedule, ->(s) { s.dig('sub_event').map { |i| i.merge({ 'start_date' => i.dig('start'), 'end_date' => i.dig('end') }) } })
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { "V-Ticket Location: #{s.dig('event_location', 'id')}" })
          .>> t(:tags_to_ids, 'v_ticket_categories', external_source_id, 'VTicket - Categories - ')
          .>> t(:tags_to_ids, 'v_ticket_tags', external_source_id, 'VTicket - Tags - ')
          .>> t(:reject_keys, ['title', 'event_location', 'sub_event', 'end', 'start'])
          .>> t(:strip_all)
        end

        def self.parse_potential_action(data, external_source_id)
          uniq_booking_urls = Array.wrap(data['sub_event']).select { |s| s.dig('bookingUrls', 0, 'url').present? }.uniq { |s| s.dig('bookingUrls', 0, 'url') }
          uniq_booking_urls.map { |sub_event|
            url = sub_event.dig('bookingUrls', 0, 'url')
            external_key = "V-Ticket OrderAction:#{Digest::SHA1.hexdigest(url)}"
            action = {}
            action_id = DataCycleCore::Thing.find_by(external_key: external_key, external_source_id: external_source_id)&.id
            action['id'] = action_id if action_id.present?
            action['name'] = "Buchungs-URL#{" (#{sub_event['start']&.in_time_zone&.strftime('%d.%m.%Y %H:%M Uhr')})" if uniq_booking_urls.size > 1}"
            action['action_type'] = Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('ActionTypes', 'Bestellen'))
            action['external_key'] = external_key
            action['url'] = url
            action
          }.compact
        end

        def self.event_period(data_hash)
          start_date = data_hash.dig('start')&.in_time_zone
          end_date = data_hash.dig('end')&.in_time_zone
          return { 'start_date' => start_date, 'end_date' => end_date } unless start_date.blank? || end_date.blank? || start_date == start_date.beginning_of_day || end_date == end_date.beginning_of_day

          sub_events_start = data_hash.dig('sub_event').map { |s| s.dig('start')&.in_time_zone }.compact
          sub_events_end = data_hash.dig('sub_event').map { |s| s.dig('end')&.in_time_zone }.compact
          start_date = sub_events_start.min if start_date.blank? || start_date == start_date.beginning_of_day
          if end_date.blank? || end_date == end_date.beginning_of_day || sub_events_end.max < sub_events_start.max
            end_date = sub_events_start.max&.end_of_day
          else
            end_date = sub_events_end.max
          end
          { 'start_date' => start_date, 'end_date' => end_date }
        end

        def self.vticket_subevent_to_subevent
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:reject_keys, ['slug', 'promoter', 'categories', 'tags', 'description'])
          .>> t(:underscore_keys)
          .>> t(:rename_keys, { 'start' => 'start_date', 'end' => 'end_date', 'location' => 'event_location' })
          .>> t(:add_field, 'url', ->(s) { s&.dig('meta', 'permalink') })
          .>> t(:nest, 'event_period', ['start_date', 'end_date'])
          .>> t(:reject_keys, ['id', 'title', 'location', 'sub_event', 'end', 'start'])
          .>> t(:strip_all)
        end

        def self.add_place_to_subevent(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { s.dig('event_location', 'id') })
          .>> t(:reject_keys, ['event_location'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
