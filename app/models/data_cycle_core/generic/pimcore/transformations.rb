# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.pimcore_to_poi(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Pimcore - Infrastructure - #{s['id']}" })
          .>> t(:unwrap, 'geoPosition', ['latitude', 'longitude'])
          .>> t(:location)
          .>> t(:nest, 'contact_info', ['url'])
          .>> t(:add_optional_field, ->(s) {  opening_hours(s) if I18n.locale.to_s == 'de' })
          .>> t(:rename_keys, { 'contentText' => 'description' })
          .>> t(:add_links, 'pimcore_city', DataCycleCore::Classification, external_source_id, ->(s) { Array(s&.dig('city'))&.map { |item| "Pimcore - City - #{item&.dig('id')}" } || [] })
          .>> t(:add_links, 'pimcore_categories', DataCycleCore::Classification, external_source_id, ->(s) { Array(s&.dig('categories'))&.map { |item| "Pimcore - Category - #{item.dig('id')}" } || [] })
          .>> t(:add_links, 'primary_image', DataCycleCore::Thing, external_source_id, ->(s) { Array("Pimcore - Image - #{s.dig('teaserImage', 'id')}") || [] }, ->(s) { s&.dig('teaserImage', 'id').present? })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { Array("Pimcore - Image - #{s.dig('imageGallery', 'id')}") || [] }, ->(s) { s&.dig('imageGallery', 'id').present? })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.pimcore_to_image(url_prefix)
          t(:stringify_keys)
          .>> t(:add_field, 'content_url', ->(s) { (url_prefix || '') + s.dig('url') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('content_url') })
          .>> t(:add_field, 'name', ->(s) { s.dig('title') || '__noname__' })
          .>> t(:add_field, 'alternative_headline', ->(s) { s.dig('alt') || s.dig('name') })
          .>> t(:add_field, 'external_key', ->(s) { "Pimcore - Image - #{s.dig('id')}" })
          .>> t(:reject_keys, ['id', 'title', 'url'])
        end

        def self.opening_hours(data)
          return if data.dig('openingTimes').blank?
          {
            'opening_hours_specification' => [
              {
                'description' => data.dig('openingTimes')
              }
            ]
          }
        end
      end
    end
  end
end
