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
          .>> t(:locale_string, 'description_long', 'longDescription')
          .>> t(:add_info, ['description', 'description_long'], external_source_id)
          .>> t(:parse_geo)
          .>> t(:location)
          .>> t(:add_links, 'imx_client', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('client', 'id').present? ? ["imx.platform - Client - #{s.dig('client', 'id')}"] : [] })
          .>> t(:universal_classifications, ->(s) { s.dig('imx_client') })
          .>> t(:add_links, 'imx_metainfos', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('metainfos')).map { |i| i.dig('productline', 'id') }.compact.map { |i| "imx.platform - metainfos - #{i}" } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('imx_metainfos') })
          .>> t(:locale_string, 'name', 'title')
          .>> t(:add_images, external_source_id)
          .>> t(:reject_keys, ['id'])
        end

        def self.to_image
          t(:locale_string, 'name', ['pooledMedium', 'title'])
          .>> t(:map_value, 'name', ->(v) { v.nil? ? '__NO_NAME__' : v })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('deeplink') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('deeplink') })
          .>> t(:add_field, 'url', ->(s) { s.dig('deeplink') })
          .>> t(:add_field, 'external_key', ->(s) { "ImxPlatform - AddressbaseImage - #{s.dig('id')}" })
          .>> t(:reject_keys, ['id'])
        end
      end
    end
  end
end
