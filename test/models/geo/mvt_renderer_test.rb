# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Geo
    class MvtRendererTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def build_renderer(x: 1, y: 1, z: 5, **)
        DataCycleCore::Geo::MvtRenderer.new(x, y, z, contents: DataCycleCore::Thing.all, **)
      end

      test 'geometry_column switches on start_points_only' do
        assert_equal('geometries.geom_simple', build_renderer.geometry_column)
        assert_equal('ST_StartPoint(geometries.geom_simple)', build_renderer(start_points_only: true).geometry_column)
      end

      test 'cluster? is false by default and true when clustering is enabled within max zoom' do
        assert_not build_renderer.cluster?
        assert_predicate build_renderer(cluster: true), :cluster?
        assert_not build_renderer(cluster: true, cluster_max_zoom: 1, z: 5).cluster?
      end

      test 'content_select_sql selects id, template_name and the transformed geometry' do
        sql = build_renderer.content_select_sql

        assert_equal(3, sql.size)
        assert(sql.any? { |s| s.include?('ST_Simplify') })
      end

      test 'allowed_geometry_types lists points and the configured non-point types' do
        assert_equal("'ST_Point'", build_renderer.allowed_geometry_types)
        assert_equal("'ST_Point', 'ST_LineString', 'ST_MultiLineString', 'ST_Polygon', 'ST_MultiPolygon'", build_renderer(cluster_lines: true, cluster_polygons: true).allowed_geometry_types)
      end

      test 'contents_with_default_scope joins geometries and intersects the tile envelope' do
        sql = build_renderer.contents_with_default_scope.to_sql

        assert_includes(sql, 'INNER JOIN geometries')
        assert_includes(sql, 'ST_Intersects')
      end

      test 'contents_with_default_scope selects the geometry type when clustering' do
        sql = build_renderer(cluster: true).contents_with_default_scope.to_sql

        assert_includes(sql, 'ST_GeometryType')
      end

      test 'mvt_unclustered_sql builds an ST_AsMVT query over the contents subquery' do
        sql = build_renderer.main_sql

        assert_includes(sql, 'WITH contents AS')
        assert_includes(sql, 'ST_AsMVT')
        assert_includes(sql, 'mvtgeom AS')
      end

      test 'mvt_clustered_sql builds the clustered and unclustered item layers' do
        sql = build_renderer(cluster: true).main_sql

        assert_includes(sql, 'clustered_items AS')
        assert_includes(sql, 'items AS')
        assert_includes(sql, 'ST_ClusterDBSCAN')
      end

      test 'mvt_cluster_sql clusters by start point for non-point clustering' do
        assert_includes(build_renderer(cluster: true, cluster_lines: true).mvt_cluster_sql, 'ST_StartPoint')
        assert_not_includes(build_renderer(cluster: true).mvt_cluster_sql, 'CASE WHEN')
      end

      test 'mvt_cluster_items_select and from include rendered items only when requested' do
        plain = build_renderer(cluster: true)

        assert_nil(plain.mvt_cluster_items_select)
        assert_equal('mvtgeom', plain.mvt_cluster_items_from)

        with_items = build_renderer(cluster: true, cluster_items: true)

        assert_includes(with_items.mvt_cluster_items_select, 'json_agg(clustered_contents.item)')
        assert_includes(with_items.mvt_cluster_items_from, 'INNER JOIN')
      end

      test 'base_contents_subquery builds linked subqueries when linked is included' do
        sql = build_renderer(include_parameters: [['linked']]).base_contents_subquery

        assert_includes(sql, 'base_things AS')
        assert_includes(sql, 'additional_things AS')
      end

      test 'render returns the unescaped tile bytes' do
        assert_nothing_raised do
          build_renderer(cache: false).render
        end
      end

      test 'render caches the tile bytes when caching is enabled' do
        assert_nothing_raised do
          build_renderer.render
        end
      end
    end
  end
end
