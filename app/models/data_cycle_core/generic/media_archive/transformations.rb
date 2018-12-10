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
          .>> t(:reject_keys, ['@context', 'visibility'])
          .>> t(:rename_keys, 'contentLocation' => 'orig_content_location')
          .>> t(:underscore_keys)
          .>> t(:tags_to_ids, 'keywords', external_source_id, 'MedienArchive - keyword - ')
          .>> t(:tags_to_ids, 'types_of_use', external_source_id, 'MedienArchive - Verwendungsart - ')
          .>> t(:tags_to_ids, 'color_space', external_source_id, 'MedienArchive - Farbraum - ')
          .>> t(:tags_to_ids, 'audiences', external_source_id, 'MedienArchive - Zielgruppe - ')
          .>> t(:tags_to_ids, 'file_type', external_source_id, 'MedienArchive - Dateiformat - ')
          .>> t(:copy_keys, 'url' => 'external_key')
          .>> t(:map_value, 'external_key', ->(s) { s.split('/').last })
          .>> t(:unwrap, 'validity_period', ['date_published', 'expires'])
          .>> t(:rename_keys,
                'date_published' => 'valid_from',
                'expires' => 'valid_until',
                'keywords' => 'keywords_medienarchive',
                'headline' => 'name')
          .>> t(:nest, 'validity_period', ['valid_from', 'valid_until'])
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { "#{s['contentType']}-#{place_template}: #{s['url'].split('/').last}" }, ->(s) { s['orig_content_location'].present? })
          .>> t(:add_link, 'photographer', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Photographer - #{s&.dig('photographer_organization', 'id')}" }, ->(s) { s['photographer_organization'].present? })
          .>> t(:add_link, 'photographer', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Photographer - #{s&.dig('photographer_person', 'id')}" }, ->(s) { s['photographer_person'].present? })
          .>> t(:add_user_link, 'created_by', ->(s) { s&.dig('accountable_person', 'email') })
          .>> t(:reject_keys, ['orig_content_location'])
          .>> t(:strip_all)
        end

        def self.media_archive_to_video(external_source_id, place_template)
          t(:stringify_keys)
          .>> t(:reject_keys, ['@context', 'visibility'])
          .>> t(:rename_keys, 'contentLocation' => 'orig_content_location')
          .>> t(:underscore_keys)
          .>> t(:tags_to_ids, 'keywords', external_source_id, 'MedienArchive - keyword - ')
          .>> t(:tags_to_ids, 'types_of_use', external_source_id, 'MedienArchive - Verwendungsart - ')
          .>> t(:tags_to_ids, 'audiences', external_source_id, 'MedienArchive - Zielgruppe - ')
          .>> t(:tags_to_ids, 'file_type', external_source_id, 'MedienArchive - Dateiformat - ')
          .>> t(:copy_keys, 'url' => 'external_key')
          .>> t(:map_value, 'external_key', ->(s) { s.split('/').last })
          .>> t(:unwrap, 'validity_period', ['date_published', 'expires'])
          .>> t(:rename_keys,
                'date_published' => 'valid_from',
                'expires' => 'valid_until',
                'keywords' => 'keywords_medienarchive',
                'headline' => 'name')
          .>> t(:add_link, 'director', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Person - #{s&.dig('director', 'id')}" })
          .>> t(:add_link, 'contributor', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Person - #{s&.dig('contributor', 'id')}" })
          .>> t(:nest, 'validity_period', ['valid_from', 'valid_until'])
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { "#{s['contentType']}-#{place_template}: #{s['url'].split('/').last}" }, ->(s) { s['orig_content_location'].present? })
          .>> t(:add_user_link, 'created_by', ->(s) { s&.dig('accountable_person', 'email') })
          .>> t(:reject_keys, ['orig_content_location'])
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
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
          .>> t(:compact)
        end
      end
    end
  end
end
