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
          .>> t(:add_field, 'opening_hours_specification', ->(s) { opening_hours(s, external_source_id, s.dig('external_key')) })
          .>> t(:rename_keys, { 'contentText' => 'text', 'shortDescription' => 'description' })
          .>> t(:map_value, 'text', ->(s) { s&.gsub("\n", '<br/>') })
          .>> t(:map_value, 'description', ->(s) { s&.gsub("\n", '<br/>') })
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

        def self.to_event(external_source_id)
          t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id, ->(s) { [Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(s.dig('organiser')).merge('organization' => true).to_s)] })
          .>> t(:add_field, 'organizer_key', ->(s) { Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(s.dig('organiser')).merge('organization' => true).to_s) })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('id') })
          .>> t(:add_field, 'pimcore_tags', ->(s) { get_tags(s) })
          .>> t(:add_links, 'pimcore_locations', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('locations'))&.map { |name| "Pimcore - Location - #{name}" } || [] })
          .>> t(:add_links, 'pimcore_categories', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('categories'))&.map { |name| "Pimcore - Event-Category - #{name}" } || [] })
          .>> t(:add_field, 'name', ->(s) { s.dig('localizedData', 'name') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { get_image_external_keys(s.dig('images')) })
          .>> t(:reject_keys, ['id', 'images'])
        end

        def self.to_place
          t(:add_field, 'external_key', ->(s) { Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(s).merge('place' => true).to_s) })
          .>> t(:rename_keys, { 'contactperson' => 'name', 'phone' => 'telephone', 'website' => 'url' })
          .>> t(:nest, 'contact_info', ['name', 'telephone', 'email', 'url'])
          .>> t(:add_field, 'address_country', ->(*) { 'AT' })
          .>> t(:rename_keys, { 'street' => 'street_address', 'zip' => 'postal_code', 'city' => 'address_locality' })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'country_code', ->(*) { [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Ländercodes', 'AT')] })
          .>> t(:add_field, 'name', ->(h) { h.dig('location')&.squish.presence || '__no_name__' })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('geo', 'latitude') })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('geo', 'longitude') })
          .>> t(:location)
        end

        def self.to_organization(external_source_id)
          t(:add_field, 'external_key', ->(s) { Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(s).except('place_key').merge('organization' => true).to_s) })
          .>> t(:rename_keys, { 'name' => 'organizer_name' })
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { [s.dig('place_key')] })
          .>> t(:add_field, 'contact_person', ->(s) { s.dig('contactperson') })
          .>> t(:rename_keys, { 'contactperson' => 'name', 'phone' => 'telephone', 'website' => 'url' })
          .>> t(:nest, 'contact_info', ['name', 'telephone', 'email', 'url'])
          .>> t(:add_field, 'address_country', ->(*) { 'AT' })
          .>> t(:rename_keys, { 'street' => 'street_address', 'zip' => 'postal_code', 'city' => 'address_locality' })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'country_code', ->(*) { [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Ländercodes', 'AT')] })
          .>> t(:add_field, 'name', ->(s) { s.dig('organizer_name')&.squish.presence || s.dig('contact_person')&.squish.presence || '__no_name__' })
        end

        def self.to_event_image
          t(:add_field, 'external_key', ->(s) { "Pimcore - EventImage - #{s.dig('link')}" })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('link') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('link') })
          .>> t(:reject_keys, ['link', 'index', 'gallery_size'])
        end

        def self.get_image_external_keys(hash)
          return [] if hash['gallery'].blank?
          hash.dig('gallery').map { |data| "Pimcore - EventImage - #{data.dig('link')}" }
        end

        def self.opening_hours(data, external_source_id, external_key)
          thing = DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)
          to_update = thing&.opening_hours_specification&.first
          attribute_hash = {}
          attribute_hash['id'] = to_update.id if to_update.present?
          attribute_hash['description'] = data.dig('openingTimes').gsub("\n", '<br/>') if data.dig('openingTimes').present?
          [attribute_hash.presence].compact
        end

        def self.get_tags(hash)
          tags = []
          tags.push('Top Event') if hash.dig('isTopEvent') == true
          tags.push('Berge Plus') if hash.dig('isBergePlus') == true
          tags.push('Empfehlung') if hash.dig('isEmpfehlung') == true
          tags.push('Bergerlebnis') if hash.dig('isBergerlebnis') == true
          tags.map do |tag_name|
            DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Pimcore - Tags', tag_name)
          end
        end
      end
    end
  end
end
