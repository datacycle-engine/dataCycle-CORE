# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Linked
        extend DataCycleCore::ContentHelper

        class << self
          def parent(content:, **_args)
            content&.related_contents&.limit(1) || DataCycleCore::Thing.none
          end

          # Returns all things that are within a certain radius of the content's location.
          # :virtual:
          #   :module: Linked
          #   :method: in_radius
          #   :radius: 50
          #   :limit: 6
          #   :unit: km
          #   :exclude_properties:
          #     - linked_thing
          def in_radius(content:, virtual_definition:, **)
            radius = virtual_definition.dig('virtual', 'radius').to_f
            return DataCycleCore::Thing.none if radius <= 0

            lon, lat = content.try(:location)&.coordinates
            return DataCycleCore::Thing.none if lat.blank? || lon.blank?

            template_name = virtual_definition['template_name']
            parameters = virtual_definition['stored_filter']
            unit = virtual_definition.dig('virtual', 'unit') || 'm'
            limit = virtual_definition.dig('virtual', 'limit')&.to_i
            excludes = virtual_definition.dig('virtual', 'exclude_properties') || []

            query = DataCycleCore::StoredFilter.new(parameters:).apply
              .where.not(id: content.id)
            query = query.where(template_name:) if template_name.present?
            query = query.limit(limit) if limit.present? && limit.positive?
            query = query.geo_radius({ 'lon' => lon, 'lat' => lat, 'distance' => radius, 'unit' => unit })
              .sort_proximity_geographic('ASC', [lon, lat])

            if excludes.present?
              exclude_ids = excludes.flat_map { |ex| content.try(ex).pluck(:id) }.compact.uniq
              query = query.where.not(id: exclude_ids) if exclude_ids.any?
            end

            query.query
          end

          def tour_start_location(content:, virtual_definition:, **)
            template_name = virtual_definition['template_name']
            return DataCycleCore::Thing.none if template_name.blank?

            line = content.try(:line)
            return DataCycleCore::Thing.none if line.blank?

            line = line.first if line.is_a?(RGeo::Geographic::SphericalMultiLineStringImpl)
            return DataCycleCore::Thing.none if line.blank?

            start_point = line.start_point
            return DataCycleCore::Thing.none if start_point.blank?

            start_location = DataCycleCore::Thing.new(template_name:)
            start_location.id = generate_uuid(content.id, start_point.to_s)
            start_location.set_memoized_attribute('location', start_point)

            DataCycleCore::Thing.where(id: start_location.id)
              .tap { |rel| rel.send(:load_records, [start_location]) }
          end
        end
      end
    end
  end
end
