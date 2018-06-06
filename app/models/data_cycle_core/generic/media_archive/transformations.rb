# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.media_archive_to_bild(external_source_id, place_template)
          t(:stringify_keys)
          .>> t(:reject_keys, ['@context', 'contentType', 'visibility', 'contentLocation'])
          .>> t(:underscore_keys)
          .>> t(:tags_to_ids, 'keywords', external_source_id, 'MedienArchive - keyword - ')
          .>> t(:tags_to_ids, 'types_of_use', external_source_id, 'MedienArchive - Verwendungsart - ')
          .>> t(:tags_to_ids, 'audiences', external_source_id, 'MedienArchive - Zielgruppe - ')
          .>> t(:copy_keys, 'url' => 'external_key')
          .>> t(:map_value, 'external_key', ->(s) { s.split('/').last })
          .>> t(:unwrap, 'validity_period', ['date_published', 'expires'])
          .>> t(:rename_keys,
                'date_published' => 'valid_from',
                'expires' => 'valid_until',
                'keywords' => 'keywords_medienarchive')
          .>> t(:nest, 'validity_period', ['valid_from', 'valid_until'])
          .>> t(
            :add_field,
            'content_location',
            lambda do |s|
              [
                DataCycleCore::Place.find_by(
                  external_source_id: external_source_id,
                  external_key: "#{s['contentType']}-#{place_template}: #{s['url'].split('/').last}"
                )&.id
              ].compact.presence
            end
          )
          .>> t(:strip_all)
        end

        def self.media_archive_to_video(external_source_id)
          t(:stringify_keys)
            .>> t(:reject_keys, ['@context', 'contentType', 'visibility', 'contentLocation'])
            .>> t(:underscore_keys)
            .>> t(:tags_to_ids, 'keywords', external_source_id, 'MedienArchive - keyword - ')
            .>> t(:tags_to_ids, 'typesOfUse', external_source_id, 'MedienArchive - Verwendungsart - ')
            .>> t(:tags_to_ids, 'audiences', external_source_id, 'MedienArchive - Zielgruppe - ')
            .>> t(:copy_keys, 'url' => 'external_key')
            .>> t(:map_value, 'external_key', ->(s) { s.split('/').last })
            .>> t(:unwrap, 'validity_period', ['date_published', 'expires'])
            .>> t(:rename_keys,
                  'date_published' => 'valid_from',
                  'expires' => 'valid_until',
                  'keywords' => 'keywords_medienarchive')
            .>> t(
              :add_field,
              'director',
              lambda do |s|
                [
                  DataCycleCore::Person.find_by(
                    external_source_id: external_source_id,
                    external_key: "Regie: #{s['url'].split('/').last}"
                  )&.id
                ].compact.presence
              end
            )
            .>> t(
              :add_field,
              'contributor',
              lambda do |s|
                [
                  DataCycleCore::Person.find_by(
                    external_source_id: external_source_id,
                    external_key: "Kamera: #{s['url'].split('/').last}"
                  )&.id
                ].compact.presence
              end
            )
            .>> t(:nest, 'validity_period', ['valid_from', 'valid_until'])
            .>> t(:strip_all)
        end

        def self.media_archive_to_content_location(template)
          t(:stringify_keys)
          .>> t(:underscore_keys)
          .>> t(:unwrap, 'geo', ['longitude', 'latitude'])
          .>> t(:rename_keys, 'address' => 'street_address')
          .>> t(:nest, 'address', ['street_address'])
          .>> t(:map_value, 'name', ->(s) { s.try :[], I18n.locale.to_s })
          .>> t(:add_field, 'external_key', ->(s) { "#{s['contentType']}-#{template}: #{s['url'].split('/').last}" })
          .>> t(:location)
          .>> t(:compact)
          .>> t(:strip_all)
        end

        def self.media_archive_to_person
          t(:stringify_keys)
          .>> t(:underscore_keys)
          .>> t(:map_value, 'given_name', ->(s) { (s.empty? ? ' ' : s) })
          .>> t(:map_value, 'family_name', ->(s) { (s.empty? ? ' ' : s) })
          .>> t(:compact)
        end
      end
    end
  end
end
