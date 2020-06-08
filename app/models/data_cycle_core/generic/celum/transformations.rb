# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.document_to_media_object(external_source_id)
          t(:stringify_keys)
          .>> t(:compact)
          .>> t(:rename_keys, { 'name' => 'old_name' })
          .>> t(:add_field, 'name', ->(s) { s.dig('old_name', '#cdata-section') })
          .>> t(:add_field, 'external_key', ->(s) { "Document:#{s.dig('id', '#cdata-section')}" })
          .>> t(:add_field, 'date_created', ->(s) { s.dig('creationDate', '#cdata-section') })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('lastModified', '#cdata-section') })
          .>> t(:add_field, 'upload_date', ->(s) { s.dig('uploadDate', '#cdata-section') })
          .>> t(:add_field, 'description', ->(s) { document_information_value(data: [s.dig('documentInformationEntries', 'documentInformationEntry')].flatten, language: 'de', type: '0', field_number: '5') })
          .>> t(:add_field, 'caption', ->(s) { document_information_value(data: [s.dig('documentInformationEntries', 'documentInformationEntry')].flatten, language: 'de', type: '0', field_number: '7') })
          .>> t(:add_field, 'license', ->(s) { document_information_value(data: [s.dig('documentInformationEntries', 'documentInformationEntry')].flatten, language: 'de', type: '0', field_number: '3') })
          .>> t(:add_field, 'types_of_use_celum', ->(s) { [parse_types_of_use([s.dig('documentInformationEntries', 'documentInformationEntry')].flatten)].compact.presence })
          .>> t(:add_links, 'keywords_celum', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('keywords', 'keyword')]&.flatten&.map { |item| item.is_a?(::Hash) ? "Keyword:#{item.values.first}" : nil }&.flatten || [] })
          .>> t(:add_links, 'folders_celum', DataCycleCore::Classification, external_source_id, ->(s) { ["Folder:#{s&.dig('folder', '#cdata-section')}"] }, ->(s) { s&.dig('folder', '#cdata-section') })
          .>> t(:add_links, 'asset_collections_celum', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('assetCollections', 'assetCollection')]&.flatten&.map { |item| item.dig('#cdata-section') }&.map { |item| "AssetCollection:#{item}" } }, ->(s) { s&.dig('assetCollections', 'assetCollection') })
          .>> t(:add_links, 'created_by_celum', DataCycleCore::Classification, external_source_id, ->(s) { ["Celum - User - #{s&.dig('createdBy', '#cdata-section') || s&.dig('user', '#cdata-section')}"] }, ->(s) { s&.dig('createdBy', '#cdata-section') || s&.dig('user', '#cdata-section') })
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

        def self.document_information_value(data:, language:, type:, field_number:)
          data
            &.select { |item| item&.dig('documentInformationField', 'type') == type && item&.dig('documentInformationField', '#cdata-section') == field_number }
            &.map { |item| item&.dig('content') }
            &.flatten
            &.select { |content| content&.dig('language', '#cdata-section') == language }
            &.map { |item| item&.dig('value', '#cdata-section') }
            &.first
        end

        def self.parse_types_of_use(data)
          DataCycleCore::ClassificationAlias
            .for_tree('Celum - Verwendungsart')
            .find_by(name: unescape_html(document_information_value(data: data, language: 'de', type: '5', field_number: '1')))
            &.classifications
            &.first
            &.id
        end

        def self.unescape_html(string)
          Nokogiri::HTML.fragment(string)&.to_s&.downcase
        end
      end
    end
  end
end
