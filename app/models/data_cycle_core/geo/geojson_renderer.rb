# frozen_string_literal: true

module DataCycleCore
  module Geo
    class GeojsonRenderer < ::DataCycleCore::Geo::Base
      # def initialize(host: nil, end_point: nil, partner: nil, **options)
      #   # ???
      #   # @host = host
      #   # @end_point = end_point
      #   # @partner = partner
      #   # @partner_lakes = options.dig(:partner_lakes)
      # end

      def to_geojson(include_without_geometry: true, simplify_factor: SIMPLIFY_FACTOR, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false)
        @include_without_geometry = include_without_geometry
        @simplify_factor = simplify_factor
        @include_parameters = include_parameters
        @fields_parameters = fields_parameters
        @classification_trees_parameters = classification_trees_parameters
        @single_item = single_item

        geojson_result(
          all.geojson_default_scope,
          geojson_sql(@single_item ? geojson_detail_select_sql : geojson_select_sql)
        )
      end
    end
  end
end
