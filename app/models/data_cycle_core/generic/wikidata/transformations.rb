# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wikidata
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.wikidata_to_poi(external_source_id)
          t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(parse_image_key(s.dig('image', 'value'))) })
          .>> t(:add_links, 'wikidata_classification', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('class'))&.presence&.map { |item| item.dig('value')&.split('/')&.last }&.compact })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('item', 'value') })
          .>> t(:add_field, 'name', ->(s) { s.dig('itemLabel', 'value') })
          .>> t(:add_field, 'description', ->(s) { s.dig('itemDescription', 'value') })
          .>> t(:add_field, 'longitude', ->(s) { get_location(s.dig('location', 'value'))&.x })
          .>> t(:add_field, 'latitude', ->(s) { get_location(s.dig('location', 'value'))&.y })
          .>> t(:location)
          .>> t(:add_field, 'url', ->(s) { s.dig('url', 'value') })
          .>> t(:nest, 'contact_info', ['url'])
          .>> t(:add_field, 'address_country', ->(s) { s.dig('countryLabel', 'value') })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('street', 'value') || s.dig('old_street', 'value') })
          .>> t(:nest, 'address', ['street_address', 'address_country'])
          .>> t(:add_field, 'country_code', ->(s) { get_country_code(s.dig('countryLabel', 'value')) })
        end

        def self.wikimedia_to_image(external_source_id)
          t(:add_links, 'wikidata_category', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('categories'))&.presence&.map { |item| "Wikidata - Image Categories - #{item}" } })
          .>> t(:add_field, 'external_key', ->(s) { "Wikidata - #{s['title']}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('imageinfo', 0, 'extmetadata', 'ObjectName', 'value') || s.dig('title') })
          .>> t(:add_field, 'description', ->(s) { s.dig('imageinfo', 0, 'extmetadata', 'ImageDescription', 'value') })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('imageinfo', 0, 'url') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { generate_thumb_url(s.dig('content_url')) })
          .>> t(:add_field, 'width', ->(s) { s.dig('imageinfo', 0, 'width') })
          .>> t(:add_field, 'height', ->(s) { s.dig('imageinfo', 0, 'height') })
          .>> t(:add_field, 'content_size', ->(s) { s.dig('imageinfo', 0, 'size') })
          .>> t(:add_field, 'upload_date', ->(s) { s.dig('imageinfo', 0, 'extmetadata', 'DateTime', 'value')&.in_time_zone })
          .>> t(:add_field, 'attribution_url', ->(s) { s.dig('imageinfo', 0, 'descriptionurl') })
          .>> t(:add_field, 'attribution_name', ->(s) { parse_attribution_name(s.dig('imageinfo', 0, 'extmetadata').slice('Artist')&.dig('Artist', 'value')) })
          .>> t(:add_field, 'license', ->(s) { s.dig('imageinfo', 0, 'extmetadata', 'LicenseUrl', 'value') || s.dig('imageinfo', 0, 'extmetadata', 'LicenseShortName', 'value') })
          .>> t(:add_field, 'wikidata_license_classification', ->(s) { [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Wikidata - Lizenzen', s.dig('imageinfo', 0, 'extmetadata', 'LicenseShortName', 'value'))] })
          .>> t(:add_field, 'mandatory_license', ->(s) { s.dig('imageinfo', 0, 'extmetadata', 'Copyrighted', 'value')&.casecmp?('true') }) # only for Bild-template in data-cycle-basic set!!
        end

        def self.generate_thumb_url(url)
          return if url.blank? == ''
          parts = url.split('/')
          return url unless parts[3] == 'wikimedia' && parts[4] == 'org'
          (parts[0..4] + ['thumb'] + parts[5..-1] + ['800px-' + parts.last]).join('/')
        end

        def self.parse_attribution_name(artist_data)
          return if artist_data.blank?
          if artist_data.match?(/[<>]/)
            Nokogiri::HTML.fragment(artist_data)&.children&.first&.children&.first&.text
          else
            artist_data
          end
        end

        def self.parse_attribution_url(artist_data)
          return if artist_data.blank?
          artist_data.match?(/[<>]/) ? artist_data : nil
        end

        def self.parse_image_key(string)
          return if string.blank?
          "Wikidata - File:#{CGI.unescape(string).split('/').last}"
        end

        def self.get_location(string)
          return nil if string.blank?
          RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt(string)
        end

        def self.get_country_code(string)
          countries = { 'Österreich' => 'AT', 'Deutschland' => 'DE', 'Schweiz' => 'CH' }
          DataCycleCore::ClassificationAlias.for_tree('Ländercodes').find_by(name: countries.dig(string))&.classifications&.ids
        end
      end
    end
  end
end
