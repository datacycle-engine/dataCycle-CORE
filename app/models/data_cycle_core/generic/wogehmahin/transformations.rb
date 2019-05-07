# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wogehmahin
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_poi(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { s.dig('identifier') })
          .>> t(:reject_keys, ['owners', 'languages', 'Genusslust', 'identifier'])
          .>> t(:add_field, 'street_address', ->(s) { s.dig('address', 'address') })
          .>> t(:unwrap, 'address')
          .>> t(
            :rename_keys,
            {
              'locality' => 'address_locality',
              'postalCode' => 'postal_code',
              'country' => 'address_country'
            }
          )
          .>> t(:map_value, 'postal_code', ->(s) { s == '0' ? nil : s })
          .>> t(:nest, 'address', ['street_address', 'address_locality', 'postal_code', 'address_country'])
          .>> t(
            :rename_keys,
            {
              'telefon' => 'telephone',
              'fax' => 'fax_number',
              'mail' => 'email',
              'web' => 'url'
            }
          )
          .>> t(:nest, 'contact_info', ['telephone', 'fax_number', 'email', 'url'])
          .>> t(:add_field, 'wogehmahin_topics', ->(s) { s.dig('topics')&.map { |item| item.dig('name') } })
          .>> t(:tags_to_ids, 'wogehmahin_topics', external_source_id, 'Wogehmahin - Topic - ')
          .>> t(:add_field, 'wogehmahin_types', ->(s) { s.dig('types')&.map { |item| item.dig('name') } })
          .>> t(:tags_to_ids, 'wogehmahin_types', external_source_id, 'Wogehmahin - Type - ')
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { s.dig('photos').map { |item| generate_key(item) } })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.to_image
          t(:stringify_keys)
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'external_key', ->(s) { generate_key(s) })
          .>> t(:strip_all)
        end

        def self.generate_key(data_hash)
          id = data_hash.dig('identifier')
          return if id.blank?
          if uuid?(id)
            id
          elsif id == 'WGH-Bild'
            'WGH - Image - ' + data_hash.dig('url').split('/').last.split('.').first
          end
        end

        def self.uuid?(data)
          data_clean = data.squish.downcase
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          data_clean.length == 36 && !(data_clean =~ uuid).nil?
        end
      end
    end
  end
end
