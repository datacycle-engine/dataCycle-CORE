# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Linked
        class << self
          def parent(content:, **_args)
            content&.related_contents&.limit(1) || DataCycleCore::Thing.none
          end

          def in_radius(content:, virtual_definition:, **)
            radius = virtual_definition.dig('virtual', 'radius').to_f
            return DataCycleCore::Thing.none if radius <= 0

            lon, lat = content.try(:location)&.coordinates
            return DataCycleCore::Thing.none if lat.blank? || lon.blank?

            unit = virtual_definition.dig('virtual', 'unit') || 'm'
            template_name = virtual_definition['template_name']
            parameters = virtual_definition['stored_filter']
            query = DataCycleCore::StoredFilter.new(parameters:).apply
              .where.not(id: content.id)
            query = query.where(template_name:) if template_name.present?

            query = query.geo_radius({ 'lon' => lon, 'lat' => lat, 'distance' => radius, 'unit' => unit })
              .sort_proximity_geographic('ASC', [lon, lat])

            query.query
          end
        end
      end
    end
  end
end
