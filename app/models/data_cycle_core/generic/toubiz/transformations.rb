# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Toubiz
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Toubiz::TransformationFunctions[*args]
        end

        def self.to_event(external_source_id)
          t(:add_field, 'external_key', ->(s) { s.dig('id') })
          .>> t(:add_ccc)
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('updatedAt')&.in_time_zone })
          .>> t(:add_info, external_source_id, ['description', 'abstract', 'additionalBookingInformation', 'currentInformation', 'additionalLocationInformation', 'additionalHostInformation'])
          .>> t(:add_potential_action, external_source_id)
          .>> t(:add_event_schedule, external_source_id)
          .>> t(:add_links, 'primary_category', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('category', 'id')) })
          .>> t(:universal_classifications, ->(s) { s.dig('primary_category') })
          .>> t(:add_links, 'secondary_categories', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('secondaryCategories'))&.map { |i| i['id'] } })
          .>> t(:universal_classifications, ->(s) { s.dig('secondary_categories') })
          .>> t(:add_links, 'tag_classifications', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('tags'))&.map { |i| "mein.toubiz - Tag - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('tag_classifications') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s['media'])&.map { |i| i['id'] } })
          .>> t(:add_things, external_source_id)
          .>> t(:reject_keys, ['id', 'fielValues', 'fieldBlueprints', 'addr', 'author', 'tags'])
        end

        def self.to_poi(external_source_id)
          t(:add_field, 'external_key', ->(s) { s.dig('id') })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('updatedAt')&.in_time_zone })
          .>> t(:location)
          .>> t(:add_ccc)
          .>> t(:rename_keys, { 'address' => 'addr' })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('addr', 'street').presence })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('addr', 'zip').presence })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('addr', 'city').presence })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('addr', 'country').presence })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_contact_info)
          .>> t(:add_info, external_source_id, ['description', 'abstract'])
          .>> t(:add_links, 'primary_category', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('primaryCategory', 'id')) })
          .>> t(:universal_classifications, ->(s) { s.dig('primary_category') })
          .>> t(:add_links, 'tag_classifications', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('tags'))&.map { |i| "mein.toubiz - Tag - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('tag_classifications') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s['media'])&.map { |i| i['id'] } })
          .>> t(:reject_keys, ['id', 'fielValues', 'fieldBlueprints', 'addr', 'author', 'tags'])
        end

        def self.to_tour(external_source_id)
          t(:add_field, 'external_key', ->(s) { s.dig('id') })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('updatedAt')&.in_time_zone })
          .>> t(:location)
          .>> t(:add_tour)
          .>> t(:add_ccc)
          .>> t(:rename_keys, { 'address' => 'addr' })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('addr', 'street').presence })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('addr', 'zip').presence })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('addr', 'city').presence })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('addr', 'country').presence })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_contact_info)
          .>> t(:add_info, external_source_id, ['description', 'abstract'])
          .>> t(:add_links, 'primary_category', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('primaryCategory', 'id')) })
          .>> t(:universal_classifications, ->(s) { s.dig('primary_category') })
          .>> t(:add_links, 'tag_classifications', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('tags'))&.map { |i| "mein.toubiz - Tag - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('tag_classifications') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s['media'])&.map { |i| i['id'] } })
          .>> t(:add_links, 'contained_in_place', DataCycleCore::Thing, external_source_id, ->(s) { [s.dig('tourStageRelations', 'parent', 'id')] }, ->(s) { s.dig('tourStageRelations', 'parent', 'id').present? })
          .>> t(:reject_keys, ['id', 'fielValues', 'fieldBlueprints', 'addr', 'author', 'tags'])
        end

        def self.to_image
          t(:add_field, 'external_key', ->(s) { s.dig('id') })
          .>> t(:map_value, 'name', ->(v) { v.presence || '__no_name__' })
          .>> t(:add_urls)
          .>> t(:reject_keys, ['id', 'author'])
        end
      end
    end
  end
end
