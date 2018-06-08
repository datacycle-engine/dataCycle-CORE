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
          .>> t(:rename_keys, { 'id' => 'external_key', 'tags' => 'event_tag' })
          .>> t(:nest, 'event_period', ['start_date', 'end_date'])
          .>> t(:tags_to_ids, 'event_tag', external_source_id, 'Veranstaltungsdatenbank - tags - ')
          .>> t(:category_key_to_ids, 'categories', external_source_id, 'CATEGORY:', 'id')
          .>> t(:rename_keys, 'categories' => 'event_category')
          .>> t(:add_link, 'location', DataCycleCore::Place, external_source_id, ->(s) { "PLACE:#{s.dig('event_location', 'id')}" })
          .>> t(:add_link, 'image', DataCycleCore::CreativeWork, external_source_id, ->(s) { "IMAGE:#{s.dig('image', 'id')}" })
          .>> t(:reject_keys, ['sub_events'])
          .>> t(:compact)
          .>> t(:strip_all)
        end

        def self.event_database_sub_item_to_sub_event(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:rename_keys, 'location' => 'event_location')
          .>> t(:add_link, 'location', DataCycleCore::Place, external_source_id, ->(s) { "PLACE:#{s.dig('event_location', 'id')}" })
          .>> t(:reject_keys, ['id', '@type', 'event_location'])
          .>> t(:underscore_keys)
          .>> t(:nest, 'event_period', ['start_date', 'end_date'])
          .>> t(:compact)
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
          .>> t(:compact)
          .>> t(:strip_all)
        end

        def self.event_database_to_image(event_name)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:underscore_keys)
          .>> t(:add_field, 'external_key', ->(s) { "IMAGE:#{s.dig('id')}" })
          .>> t(:add_field, 'headline', ->(_s) { event_name })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('content_url') })
          .>> t(:map_value, 'width', ->(s) { s&.to_i })
          .>> t(:map_value, 'height', ->(s) { s&.to_i })
          .>> t(:reject_keys, ['id', '@type'])
          .>> t(:compact)
          .>> t(:strip_all)
        end
      end
    end
  end
end
