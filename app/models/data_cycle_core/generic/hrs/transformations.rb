# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Hrs
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.hrs_to_unterkunft(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'latitude', ->(s) { s.dig('o_gps', 'latitude', 'text')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('o_gps', 'longitude', 'text')&.to_f })
          .>> t(:location)
          .>> t(:add_field, 'name', ->(s) { s.dig('o_bezeichnung', 'text') })
          .>> t(:add_field, 'description', ->(s) { s.dig('o_bemerkung', 'text') })
          .>> t(:add_field, 'text', ->(s) { s.dig('o_lage', 'text') })
          .>> t(:add_field, 'url', ->(s) { s.dig('o_url', 'text') })
          .>> t(:nest, 'contact_info', ['url'])
          .>> t(:add_field, 'street_address', ->(s) { s.dig('o_strasse', 'text') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('o_plz', 'text') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('o_ort', 'text') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('o_land', 'iso3166_alpha2') })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_links, 'hrs_categories', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('o_category', 'category')]&.compact&.flatten&.map { |item| "HRS - Category - #{item.dig('position')}" }&.flatten || [] })
          .>> t(:add_links, 'hrs_facilities', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('o_ausstattung', 'ausstattung')]&.compact&.flatten&.map { |item| "HRS - Facility - #{item.dig('position')}" }&.flatten || [] })
          .>> t(:add_links, 'hrs_target_groups', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('o_leisure', 'leisure')]&.compact&.flatten&.map { |item| "HRS - Target-Group - #{item.dig('position')}" }&.flatten || [] })
          .>> t(:add_links, 'hrs_stars', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('o_sterne', 'text')&.to_i]&.compact&.flatten&.map { |item| "HRS - Star - #{item}" }&.flatten || [] })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s&.dig('o_bild', 'bild')).compact&.map { |item| image_id(item.dig('text')) } })
          .>> t(:add_field, 'external_key', ->(s) { "HRS - #{s.dig('o_id', 'text')}" })
          .>> t(:reject_keys, ['id', 'o_id', 'o_gps', 'o_bezeichnung', 'o_url', 'o_ort', 'o_strasse', 'o_plz', 'o_ort', 'o_land', 'o_bemerkung', 'o_lage'])
          .>> t(:strip_all)
        end

        def self.hrs_to_image
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { image_id(s&.dig('text')) })
          .>> t(:add_field, 'name', ->(s) { s.dig('beschreibung') || '__noname__' })
          .>> t(:add_field, 'width', ->(_s) { 1024 })
          .>> t(:add_field, 'height', ->(_s) { 768 })
          .>> t(:add_field, 'thumbnail_url', ->(s) { url_size(s&.dig('text'), 'sm') })
          .>> t(:add_field, 'content_url', ->(s) { url_size(s&.dig('text'), 'xl') })
          .>> t(:add_field, 'hrs_image_categories', ->(s) { [DataCycleCore::ClassificationAlias.for_tree('HRS - Image-Categories').find_by(name: s.dig('category'))&.classifications&.first&.id] if s.dig('category').present? })
          .>> t(:strip_all)
        end

        def self.image_id(url)
          return if url.blank?
          ids = url.split('/')
          array = ids[0..-2] + ids.last.split('_')
          [array[4], array[5], array[7]].join('_')
        end

        def self.url_size(url, size_para)
          return if url.blank?
          ids = url.split('/')
          file_name = ids.last
          file_components = file_name.split('_')
          _size, extention = file_components.last.split('.')
          file_name = [size_para, extention].join('.')
          file_components = (file_components[0..-2] + [file_name]).join('_')
          (ids[0..-2] + [file_components]).join('/')
        end
      end
    end
  end
end
