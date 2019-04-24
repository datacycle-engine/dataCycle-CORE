# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.pimcore_to_poi(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Pimcore - Infrastructure - #{s['id']}" })
          .>> t(:unwrap, 'geoPosition', ['latitude', 'longitude'])
          .>> t(:location)
          .>> t(:nest, 'contact_info', ['url'])
          .>> t(:add_field, 'opening_hours_specification', ->(s) { [{ 'description' => s.dig('openingTimes') }] })
          .>> t(:rename_keys, { 'contentText' => 'description' })
          .>> t(:add_links, 'pimcore_city', DataCycleCore::Classification, external_source_id, ->(s) { Array(s&.dig('city'))&.map { |item| "Pimcore - City - #{item&.dig('id')}" } || [] })
          .>> t(:add_links, 'pimcore_categories', DataCycleCore::Classification, external_source_id, ->(s) { Array(s&.dig('categories'))&.map { |item| "Pimcore - Category - #{item.dig('id')}" } || [] })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
