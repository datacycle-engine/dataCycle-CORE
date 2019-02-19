# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.document_to_bild(external_source_id)
          t(:stringify_keys)
          .>> t(:compact)
          .>> t(:rename_keys, { 'name' => 'old_name' })
          .>> t(:add_field, 'name', ->(s) { s.dig('old_name', '#cdata-section') })
          .>> t(:add_field, 'external_key', ->(s) { "Document:#{s.dig('id', '#cdata-section')}" })
          .>> t(:add_field, 'date_created', ->(s) { s.dig('creationDate', '#cdata-section') })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('lastModified', '#cdata-section') })
          .>> t(:add_links, 'keywords_celum', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('keywords', 'keyword')]&.flatten&.map { |item| item.is_a?(::Hash) ? "Keyword:#{item.values.first}" : nil }&.flatten || [] })
          .>> t(:add_links, 'folders_celum', DataCycleCore::Classification, external_source_id, ->(s) { ["Folder:#{s&.dig('folder', '#cdata-section')}"] }, ->(s) { s&.dig('folder', '#cdata-section') })
          .>> t(
            :reject_keys,
            [
              'parent', 'postion', 'lastModified', 'root', 'tag', 'class', 'id',
              'creationDate', 'mainKeyword', 'transferred', 'allParentIds',
              'assetType', 'defaultSystemLocale', 'old_name', 'path', 'translatable',
              'tagUrl', 'nrOfChildren', 'additionalLanguages', 'userPermissions',
              'permissions'
            ]
          )
          .>> t(:strip_all)
        end

        def self.user_to_person(_external_source_id)
          t(:stringify_keys)
          .>> t(
            :rename_keys,
            {
              'id' => 'external_id',
              'firstname' => 'given_name',
              'lastname' => 'family_name',
              'fax' => 'fax_number',
              'homepage' => 'url',
              'street' => 'street_address',
              'zip' => 'postal_code',
              'city' => 'address_locality',
              'country' => 'address_country'
            }
          )
          .>> t(:add_field, 'telephone', ->(s) { s&.dig('phoneMobile') || s&.dig('phone') })
          .>> t(:map_value, 'given_name', ->(v) { v || '_' })
          .>> t(:nest, 'contact_info', ['telephone', 'fax_number', 'email', 'url'])
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'external_key', ->(s) { "User:#{s.dig('external_id')}" })
          .>> t(:add_field, 'date_created', ->(s) { s.dig('created') })
          .>> t(:strip_all)
        end
      end
    end
  end
end
