# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for ClassificationPolygon's spatial class-methods. The read aggregates
  # (to_bbox/to_mvt/combined_geojson) are executed over the empty table - that still
  # exercises the full SQL construction and the unescape/extract tail - while
  # upsert_all_geoms is driven once with a real geometry to cover the slice/insert loop.
  class ClassificationPolygonCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'to_bbox builds and runs the extent json query' do
      assert_nothing_raised { DataCycleCore::ClassificationPolygon.to_bbox }
    end

    test 'to_mvt builds and runs the MVT tile query (named and default layer)' do
      # to_mvt's SELECT references the table by the singular association name; that
      # alias only exists when the caller both joins AND filters via the association
      # hash, exactly as Mvt::V1::ClassificationTreesController#select does.
      relation = DataCycleCore::ClassificationPolygon
        .joins(:classification_alias)
        .where(classification_alias: { id: [SecureRandom.uuid] })

      assert_nothing_raised { relation.to_mvt(0, 0, 0, 'dcConcepts') }
      assert_nothing_raised { relation.to_mvt(0, 0, 0, nil) }
    end

    test 'combined_geojson builds and runs the union geojson query' do
      assert_nothing_raised { DataCycleCore::ClassificationPolygon.combined_geojson }
    end

    test 'upsert_all_geoms returns 0 for blank data and inserts the slices otherwise' do
      assert_equal 0, DataCycleCore::ClassificationPolygon.upsert_all_geoms([])
      assert_equal 0, DataCycleCore::ClassificationPolygon.upsert_all_geoms(nil)

      alias_id = DataCycleCore::ClassificationAlias.first.id
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      geom = factory.point(11.0, 47.0)

      # geom_simple is a generated column - only geom is inserted.
      count = DataCycleCore::ClassificationPolygon.upsert_all_geoms(
        [{ classification_alias_id: alias_id, geom: }]
      )

      assert_equal 1, count
    end
  end
end
