# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OpenDestinationOne
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_event(external_source_id)
          t(:underscore_keys)
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { [hash_to_key(s.dig('location'))] })
          .>> t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id, ->(s) { hash_to_key(s.dig('organizer')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s.dig('image'))&.map { |i| i.dig('url') } })
          .>> t(:add_links, 'open_destination_one_keywords', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('keywords'))&.map { |i| "open.destination.one - Keyword - #{i}" } })
          .>> t(:nest, 'event_period', ['start_date', 'end_date'])
          .>> t(:event_schedule, ->(*) { nil })
          .>> t(:rename_keys, { 'license' => 'attribution_url', 'identifier' => 'external_key' })
          .>> t(:reject_keys, ['@context', '@type', 'location', 'keywords'])
        end

        def self.to_place
          t(:underscore_keys)
          .>> t(:add_field, 'external_key', ->(s) { hash_to_key(s) })
          .>> t(:add_field, 'country_code', ->(s) { s.dig('address', 'address_country') == 'Deutschland' ? [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Ländercodes', 'DE')] : [] })
        end

        def self.to_image
          t(:add_field, 'external_key', ->(s) { s.dig('url') })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('url') })
        end

        def self.to_organizer
          t(:underscore_keys)
          .>> t(:add_field, 'external_key', ->(s) { hash_to_key(s) })
          .>> t(:nest, 'contact_info', ['url', 'fax_number', 'telephone', 'email'])
          .>> t(:reject_keys, ['@type'])
        end

        def self.hash_to_key(s)
          Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(s).to_s)
        end
      end
    end
  end
end
