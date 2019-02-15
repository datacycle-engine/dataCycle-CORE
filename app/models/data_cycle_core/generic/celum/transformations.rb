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
          .>> t(:add_links, 'keywords_celum', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('keywords', 'keyword')]&.flatten&.map { |item| "Keyword:#{item.values.first}" } || [] })
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
      end
    end
  end
end
