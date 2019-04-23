# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GooglePlaces
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.google_places_to_poi(external_source_id)
          t(:stringify_keys)
          .>> t(:reject_keys, ['id', 'photos', 'adr_address', 'reviews', 'url'])
          .>> t(:rename_keys,
                'website' => 'url',
                'place_id' => 'external_key')
          .>> t(:add_field, 'telephone', ->(s) { s.dig('formatted_phone_number') || s.dig('international_phone_number') })
          .>> t(:add_field, 'latitude', ->(s) { s['geometry'].try(:[], 'location').try(:[], 'lat').try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s['geometry'].try(:[], 'location').try(:[], 'lng').try(:to_f) })
          .>> t(:location)
          .>> t(:tags_to_ids, 'types', external_source_id, 'GooglePlaces - Tags - ')
          .>> t(:rename_keys, { 'types' => 'google_tags' })
          .>> t(:add_field, 'street_number', ->(s) { s['address_components'].select { |item| item['types'].include?('street_number') }&.first.try(:[], 'long_name') })
          .>> t(:add_field, 'street_name', ->(s) { s['address_components'].select { |item| item['types'].include?('route') }&.first.try(:[], 'long_name') })
          .>> t(:add_field, 'street_address', ->(s) { [s['street_name'], s['street_number']].join(' ') })
          .>> t(:add_field, 'address_locality', ->(s) { s['address_components'].select { |item| item['types'].include?('locality') }&.first.try(:[], 'long_name') })
          .>> t(:add_field, 'postal_code', ->(s) { s['address_components'].select { |item| item['types'].include?('postal_code') }&.first.try(:[], 'long_name') })
          .>> t(:add_field, 'address_country', ->(s) { s['address_components'].select { |item| item['types'].include?('country') }&.first.try(:[], 'long_name') })
          .>> t(:nest, 'address', ['street_address', 'address_locality', 'address_country', 'postal_code'])
          .>> t(:nest, 'contact_info', ['telephone', 'url'])
          .>> t(:add_field, 'opening_hours', ->(s) { parse_opening_hours(s.dig('opening_hours', 'periods')) })
          .>> t(:reject_keys, ['geometry', 'address_components'])
          .>> t(:strip_all)
        end

        def self.parse_opening_hours(periods)
          opening_hours_specifications = nil
          if periods.present? && periods.size == 1 && periods.first.size == 1 && periods.first.dig('open', 'day').zero? && periods.first.dig('open', 'time') == '0000'
            # --> always open
            opening_hours_specifications = (0..6).map do |item|
              {
                opens: '00:00',
                closes: '23:59',
                day_of_week: [load_day_of_week_id(item)]
              }
            end
          elsif periods.present?
            opening_hours_specifications = periods.map do |item|
              opens = item.dig('open', 'time')
              closes = item.dig('close', 'time')
              day_of_week = item.dig('open', 'day')
              {
                opens: "#{opens[0..1]}:#{opens[2..3]}",
                closes: "#{closes[0..1]}:#{closes[2..3]}",
                day_of_week: [load_day_of_week_id(day_of_week)]
              }.with_indifferent_access
            end
          end
          opening_hours_specifications
        end

        def self.load_day_of_week_id(number)
          return nil if number.negative? || number > 6
          day_hash = {
            1 => 'Montag',
            2 => 'Dienstag',
            3 => 'Mittwoch',
            4 => 'Donnerstag',
            5 => 'Freitag',
            6 => 'Samstag',
            0 => 'Sonntag'
          }
          DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
            .where('classification_tree_labels.name = ?', 'Wochentage')
            .where('classification_aliases.name = ?', day_hash[number]).first!.id
        end
      end
    end
  end
end
