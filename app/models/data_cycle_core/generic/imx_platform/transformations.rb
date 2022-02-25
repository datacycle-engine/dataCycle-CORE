# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ImxPlatform
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::ImxPlatform::TransformationFunctions[*args]
        end

        def self.to_poi(external_source_id)
          t(:add_field, 'external_key', ->(s) { "ImxPlatform - PoiId - #{s.dig('id')}" })
          .>> t(:parse_contact)
          .>> t(:locale_string, 'description', 'shortDescription')
          .>> t(:locale_string, 'text', 'longDescription')
          .>> t(:parse_geo)
          .>> t(:location)
          .>> t(:locale_string, 'name', 'title')
          .>> t(:add_images, external_source_id)
          .>> t(:reject_keys, ['id'])
        end
        # .>> t(:add_field, 'additional_information', ->(s) { to_additional_information(s, 'place', external_source_id) })
        # .>> t(:add_field, 'author', ->(s) { s.dig('meta', 'author') })
        # .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('images', 'image')&.map { |item| item&.dig('id') } || [] })
        # .>> t(:add_links, 'primary_image', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('primaryImage')&.dig('id') })
        # .>> t(:add_links, 'regions', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('regions', 'region')&.map { |item| "REGION:#{item&.dig('id')}" } || [] })
        # .>> t(:add_links, 'source', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('meta', 'source', 'id').present? ? ["SOURCE:#{s&.dig('meta', 'source', 'id')}"] : [] })
        # .>> t(:load_category, 'poi_categories', external_source_id, ->(s) { s&.dig('category', 'id').present? ? "CATEGORY:#{s&.dig('category', 'id')}" : nil })
        # .>> t(:load_category, 'frontend_type', external_source_id, ->(s) { s&.dig('frontendtype').present? ? "FRONTENDTYPE:#{Digest::MD5.new.update(s.dig('frontendtype')).hexdigest}" : nil })
        # .>> t(:category_key_to_ids, 'outdoor_active_tags', ->(s) { s&.dig('properties', 'property') }, nil, external_source_id, 'TAG:', 'tag')

        def self.to_image
          t(:locale_string, 'name', ['pooledMedium', 'title'])
          .>> t(:add_field, 'content_url', ->(s) { s.dig('deeplink') })
          .>> t(:add_field, 'external_key', ->(s) { "ImxPlatform - AddressbaseImage - #{s.dig('id')}" })
          .>> t(:reject_keys, ['id'])
        end
      end
    end
  end
end
