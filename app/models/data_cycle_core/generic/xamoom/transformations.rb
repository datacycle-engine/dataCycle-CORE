# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.xamoom_to_poi(external_source_id)
          t(:stringify_keys)
          .>> t(:unwrap, 'attributes', ['position-latitude', 'position-longitude', 'tags', 'description', 'name'])
          .>> t(:rename_keys, { 'position-latitude' => 'latitude', 'position-longitude' => 'longitude' })
          .>> t(:map_value, 'latitude', ->(s) { s.to_f })
          .>> t(:map_value, 'longitude', ->(s) { s.to_f })
          .>> t(:location)
          .>> t(:tags_to_ids, 'tags', external_source_id, 'Xamoom - tag - ')
          .>> t(:rename_keys, { 'tags' => 'xamoom_tags' })
          .>> t(:add_link, 'image', DataCycleCore::Thing, external_source_id, ->(s) { s.dig('attributes', 'image').present? ? "Xamoom - #{s['id']} - image" : nil })
          .>> t(:add_field, 'external_key', ->(s) { "Xamoom - #{s['id']}" })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.xamoom_to_image
          t(:stringify_keys)
          .>> t(:unwrap, 'attributes', ['name', 'image'])
          .>> t(:rename_keys, { 'image' => 'thumbnail_url' })
          .>> t(:add_field, 'content_url', ->(s) { s['thumbnail_url'] })
          .>> t(:add_field, 'external_key', ->(s) { "Xamoom - #{s['id']} - image" })
          .>> t(:reject_keys, ['attributes', 'id'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
