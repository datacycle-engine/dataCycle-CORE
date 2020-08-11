# frozen_string_literal: true

module DataCycleCore
  module Generic
    module EventDatabase
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.event_database_item_to_event(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:reject_keys, ['@context', '@type', 'allDay'])
          .>> t(:underscore_keys)
          .>> t(:rename_keys, { 'id' => 'external_key', 'tags' => 'event_tag', 'location' => 'event_location', 'sub_events' => 'sub_event' })
          .>> t(:map_value, 'sub_event', ->(s) { s.map { |i| DataCycleCore::Generic::Common::Functions.underscore_keys(i) } })
          .>> t(:add_field, 'event_period', ->(s) { event_period(s) })
          .>> t(:reject_keys, ['start_date', 'end_date'])
          .>> t(:event_schedule, ->(s) { s.dig('sub_event') })
          .>> t(:tags_to_ids, 'event_tag', external_source_id, 'Veranstaltungsdatenbank - tags - ')
          .>> t(:category_key_to_ids, 'categories', ->(s) { s.dig('categories') }, 'name', external_source_id, 'CATEGORY:', 'id')
          .>> t(:rename_keys, 'categories' => 'event_category')
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { "PLACE:#{s.dig('event_location', 'id')}" })
          .>> t(:add_link, 'image', DataCycleCore::Thing, external_source_id, ->(s) { "IMAGE:#{s.dig('image', 'id')}" })
          .>> t(:strip_all)
        end

        def self.event_period(data_hash)
          start_date = data_hash.dig('start_date')&.in_time_zone
          end_date = data_hash.dig('end_date')&.in_time_zone
          return { 'start_date' => start_date, 'end_date' => end_date } unless start_date.blank? || end_date.blank? || start_date == start_date.beginning_of_day || end_date == end_date.beginning_of_day

          sub_events_start = data_hash.dig('sub_event').map { |s| s.dig('start_date')&.in_time_zone }.compact
          sub_events_end = data_hash.dig('sub_event').map { |s| s.dig('end_date')&.in_time_zone }.compact
          start_date = sub_events_start.min if start_date.blank? || start_date == start_date.beginning_of_day
          if end_date.blank? || end_date == end_date.beginning_of_day || sub_events_end.max < sub_events_start.max
            end_date = sub_events_start.max.end_of_day
          else
            end_date = sub_events_end.max
          end
          { 'start_date' => start_date, 'end_date' => end_date }
        end

        def self.event_database_sub_item_to_sub_event
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:reject_keys, ['id', '@type', 'event_location'])
          .>> t(:underscore_keys)
          .>> t(:nest, 'event_period', ['start_date', 'end_date'])
          .>> t(:strip_all)
        end

        def self.event_database_location_to_content_location
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:underscore_keys)
          .>> t(:add_field, 'latitude', ->(s) { s['geo'].try(:[], 'latitude').to_f })
          .>> t(:add_field, 'longitude', ->(s) { s['geo'].try(:[], 'longitude').to_f })
          .>> t(:add_field, 'external_key', ->(s) { "PLACE:#{s['id']}" })
          .>> t(:location)
          .>> t(:unwrap, 'address', ['street_address', 'postal_code', 'address_country', 'address_locality'])
          .>> t(:reject_keys, ['id', 'geo', '@type', 'address'])
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_country', 'address_locality'])
          .>> t(:strip_all)
        end

        def self.event_database_to_image(event_name)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:underscore_keys)
          .>> t(:add_field, 'external_key', ->(s) { "IMAGE:#{s.dig('id')}" })
          .>> t(:add_field, 'name', ->(_s) { event_name })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('content_url') })
          .>> t(:map_value, 'width', ->(s) { s&.to_i })
          .>> t(:map_value, 'height', ->(s) { s&.to_i })
          .>> t(:reject_keys, ['id', '@type'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
