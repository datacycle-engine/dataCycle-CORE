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
          .>> t(:tags_to_ids, 'keywords', external_source_id, 'MedienArchive - keyword - ', ->(s) { s&.key?('keywords') })
          .>> t(:add_links, 'keyword_ids', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('keyword_ids')&.map { |k| "MedienArchive - keyword - #{k['id']}" } }, ->(s) { s&.dig('keyword_ids').present? })
          .>> t(:tags_to_ids, 'types_of_use', external_source_id, 'MedienArchive - Verwendungsart - ')
          .>> t(:tags_to_ids, 'color_space', external_source_id, 'MedienArchive - Farbraum - ')
          .>> t(:tags_to_ids, 'audiences', external_source_id, 'MedienArchive - Zielgruppe - ')
          .>> t(:tags_to_ids, 'suggested_audiences', external_source_id, 'MedienArchive - Zielgruppenvorschlag - ')
          .>> t(:tags_to_ids, 'file_type', external_source_id, 'MedienArchive - Dateiformat - ')
          .>> t(:copy_keys, 'url' => 'external_key')
          .>> t(:map_value, 'external_key', ->(s) { s.split('/').last })
          .>> t(:unwrap, 'validity_period', ['date_published', 'expires'])
          .>> t(:rename_keys,
                'date_published' => 'valid_from',
                'expires' => 'valid_until',
                'keywords' => 'keywords_medienarchive',
                'keyword_ids' => 'keywords_medienarchive',
                'headline' => 'name')
          .>> t(:nest, 'validity_period', ['valid_from', 'valid_until'])
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { "#{s['contentType']}-#{place_template}: #{s['external_key']}" }, ->(s) { s['orig_content_location'].present? })
          .>> t(:add_link, 'photographer', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Photographer - #{s&.dig('photographer_organization', 'id')}" }, ->(s) { s['photographer_organization'].present? })
          .>> t(:add_link, 'photographer', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Photographer - #{s&.dig('photographer_person', 'id')}" }, ->(s) { s['photographer_person'].present? })
          .>> t(:add_link, 'author', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Photographer - #{s&.dig('author_organization', 'id')}" }, ->(s) { s['author_organization'].present? })
          .>> t(:add_link, 'author', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Photographer - #{s&.dig('author_person', 'id')}" }, ->(s) { s['author_person'].present? })
          .>> t(:add_link, 'copyright_holder', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - CopyrightHolder - #{s&.dig('copyright_organization', 'id')}" }, ->(s) { s['copyright_organization'].present? })
          .>> t(:add_link, 'copyright_holder', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - CopyrightHolder - #{s&.dig('copyright_person', 'id')}" }, ->(s) { s['copyright_person'].present? })
          .>> t(:add_user_link, 'created_by', ->(s) { s&.dig('accountable_person', 'email') })
          .>> t(:reject_keys, ['orig_content_location'])
          .>> t(:strip_all)
        end

        def self.media_archive_to_video(external_source_id, place_template)
          t(:stringify_keys)
          .>> t(:reject_keys, ['@context', 'visibility'])
          .>> t(:rename_keys, 'contentLocation' => 'orig_content_location')
          .>> t(:underscore_keys)
          .>> t(:tags_to_ids, 'keywords', external_source_id, 'MedienArchive - keyword - ', ->(s) { s&.key?('keywords') })
          .>> t(:add_links, 'keyword_ids', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('keyword_ids')&.map { |k| "MedienArchive - keyword - #{k['id']}" } }, ->(s) { s&.dig('keyword_ids').present? })
          .>> t(:tags_to_ids, 'types_of_use', external_source_id, 'MedienArchive - Verwendungsart - ')
          .>> t(:tags_to_ids, 'audiences', external_source_id, 'MedienArchive - Zielgruppe - ')
          .>> t(:tags_to_ids, 'suggested_audiences', external_source_id, 'MedienArchive - Zielgruppenvorschlag - ')
          .>> t(:tags_to_ids, 'file_type', external_source_id, 'MedienArchive - Dateiformat - ')
          .>> t(:copy_keys, 'url' => 'external_key')
          .>> t(:map_value, 'external_key', ->(s) { s.split('/').last })
          .>> t(:unwrap, 'validity_period', ['date_published', 'expires'])
          .>> t(:rename_keys,
                'date_published' => 'valid_from',
                'expires' => 'valid_until',
                'keywords' => 'keywords_medienarchive',
                'keyword_ids' => 'keywords_medienarchive',
                'image' => 'thumbnail_url',
                'headline' => 'name')
          .>> t(:add_link, 'director', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Person - #{s&.dig('director', 'id')}" }, ->(s) { s&.dig('director').present? })
          .>> t(:add_link, 'contributor', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - Person - #{s&.dig('contributor', 'id')}" }, ->(s) { s&.dig('contributor').present? })
          .>> t(:nest, 'validity_period', ['valid_from', 'valid_until'])
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { "#{s['contentType']}-#{place_template}: #{s['url'].split('/').last}" }, ->(s) { s['orig_content_location'].present? })
          .>> t(:add_link, 'copyright_holder', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - CopyrightHolder - #{s&.dig('copyright_organization', 'id')}" }, ->(s) { s['copyright_organization'].present? })
          .>> t(:add_link, 'copyright_holder', DataCycleCore::Thing, external_source_id, ->(s) { "MedienArchive - CopyrightHolder - #{s&.dig('copyright_person', 'id')}" }, ->(s) { s['copyright_person'].present? })
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
          .>> t(:add_field, 'external_key', ->(s) { "-#{template}: #{s['url'].split('/').last}" })
          .>> t(:location)
          .>> t(:strip_all)
        end

        def self.media_archive_to_person(external_source_id)
          t(:stringify_keys)
          .>> t(:underscore_keys)
          .>> t(:reject_keys, ['id'])
          .>> t(:add_link, 'member_of', DataCycleCore::Thing, external_source_id, ->(s) { Digest::SHA1.hexdigest(s.dig('member_of', 'name')) }, ->(s) { s&.dig('member_of', 'name').present? })
          .>> t(:strip_all)
        end
      end
    end
  end
end
