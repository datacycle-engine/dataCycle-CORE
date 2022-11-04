# frozen_string_literal: true

module DataCycleCore
  module Geo
    class Base
      def initialize(host: nil, end_point: nil, partner: nil, **options)
        # ???
        # @host = host
        # @end_point = end_point
        # @partner = partner
        # @partner_lakes = options.dig(:partner_lakes)
      end

      def geojson_default_scope
        query = all.except(:order).select(geojson_content_select_sql)

        joins = geojson_include_config.pluck(:joins)
        joins.uniq!
        joins.compact!

        joins.each { |join| query = query.joins(join.squish) }

        query
      end
    end
  end
end
