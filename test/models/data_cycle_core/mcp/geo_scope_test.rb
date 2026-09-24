# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for GeoScope's cascade semantics: resolution order, precedence of the stages and --
    # the actual purpose of the class -- that a stage blocks the next one only when it can decide
    # anything for the place in question at all.
    #
    # Built with a tree of its own per test run (SecureRandom names), so the assertions do not depend
    # on the seed data's classification trees.
    class GeoScopeTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # stub_geo_scope_feature/reset_geo_scope_feature: shared with the integration test of the MCP
      # tools, so both set the same configuration by the same route.
      include DataCycleCore::McpTestHelper

      # Two rectangles: land encloses region_inside completely, region_outside lies beside it.
      LAND_WKT = 'POLYGON((10 47, 11 47, 11 48, 10 48, 10 47))'
      REGION_INSIDE_WKT = 'POLYGON((10.2 47.2, 10.8 47.2, 10.8 47.8, 10.2 47.8, 10.2 47.2))'
      REGION_OUTSIDE_WKT = 'POLYGON((20 57, 21 57, 21 58, 20 58, 20 57))'

      # 'Artikel' rather than 'LodgingBusiness': the test setup seeds no accommodation template. The
      # template name is irrelevant to the cascade -- it reads exclusively
      # collected_concept_contents and things.metadata->'address'.
      TEMPLATE_NAME = 'Artikel'

      before(:all) do
        @admin_tree = create_concept_scheme
        @region_tree = create_concept_scheme

        @land = create_concept(@admin_tree, ['Testland'], polygon: LAND_WKT)
        @municipality = create_concept(@admin_tree, ['Testland', 'Gemeinde Testdorf'])
        @region_inside = create_concept(@region_tree, ['Testregion Innen'], polygon: REGION_INSIDE_WKT)
        @region_outside = create_concept(@region_tree, ['Testregion Aussen'], polygon: REGION_OUTSIDE_WKT)

        stub_geo_scope_feature(resolution_trees: [@admin_tree.name], geo_region_trees: [@region_tree.name], locality_prefixes: ['Gemeinde'])
      end

      # Reset per test, not only after the suite: individual tests change the configuration on
      # purpose (tree priority, postal-code patterns), and the order of the tests is random.
      setup do
        stub_geo_scope_feature(resolution_trees: [@admin_tree.name], geo_region_trees: [@region_tree.name], locality_prefixes: ['Gemeinde'])
      end

      after(:all) do
        reset_geo_scope_feature
      end

      test 'resolve matches the concept name case-insensitively and returns nil for unknown or blank places' do
        assert_equal @land.id, DataCycleCore::Mcp::GeoScope.resolve('testland').anchor.id
        assert_nil DataCycleCore::Mcp::GeoScope.resolve('Nirgendwo')
        assert_nil DataCycleCore::Mcp::GeoScope.resolve('')
        assert_nil DataCycleCore::Mcp::GeoScope.resolve(nil)
      end

      # A substring match would hit "Testregion Innen" for the input "Testregion" and silently shift
      # the filter to a sub-region.
      test 'resolve does not match on substrings' do
        assert_nil DataCycleCore::Mcp::GeoScope.resolve('Testlan')
        assert_nil DataCycleCore::Mcp::GeoScope.resolve('Testland Nord')
      end

      # Regression test: the resolution ran through ILIKE, where '%' and '_' are wildcards. The place
      # name comes from an LLM, i.e. from a source that does send such characters -- and with that,
      # substring resolution was back through the back door. Measured in vcloud-dev: place: "%"
      # resolved to "Schweiz/Suisse/Svizzera/Svizra", "Vorarl%" to "Vorarlberg", "V%g" to
      # "Vahlberg". The filter then applies to a different region than the one asked for, and the hit
      # count looks plausible.
      test 'resolve treats LIKE wildcards in the place name as literal characters' do
        assert_nil DataCycleCore::Mcp::GeoScope.resolve('Testl%')
        assert_nil DataCycleCore::Mcp::GeoScope.resolve('Testlan_')
        assert_nil DataCycleCore::Mcp::GeoScope.resolve('%')
        assert_nil DataCycleCore::Mcp::GeoScope.resolve('T%d')
      end

      # The feature flag from features.yml has to take effect: without this check, :enabled: false
      # was a setting without consequence -- the place filter kept applying, and an instance that had
      # deliberately switched the cascade off would still have filtered on it.
      test 'resolve returns nil while the feature is disabled' do
        stub_geo_scope_feature(resolution_trees: [@admin_tree.name], geo_region_trees: [], enabled: false)

        assert_nil DataCycleCore::Mcp::GeoScope.resolve('Testland')

        stub_geo_scope_feature(resolution_trees: [@admin_tree.name], geo_region_trees: [])

        assert_not_nil DataCycleCore::Mcp::GeoScope.resolve('Testland')
      end

      # Without a configured resolution tree there is no cascade. Important because the tree name
      # comes exclusively from the configuration (no instance-specific default in the code).
      test 'resolve returns nil when no resolution tree is configured' do
        stub_geo_scope_feature(resolution_trees: [], geo_region_trees: [])

        assert_nil DataCycleCore::Mcp::GeoScope.resolve('Testland')
      end

      # The stage list STAGES and the two case dispatchers must stay together: a silent nil for an
      # unknown stage landed in the SQL as "... OR  OR ..." instead of as a clear error.
      test 'an unknown stage raises instead of producing broken sql' do
        scope = DataCycleCore::Mcp::GeoScope.resolve('Testland')

        assert_raises(ArgumentError) { scope.send(:stage_sql, :elevation) }
        assert_raises(ArgumentError) { scope.send(:stage_resolved?, :elevation) }
      end

      # The resolved tree follows the configuration order, not the order of discovery in the
      # database: in practice the same place name exists in several trees (four "Vorarlberg"s in
      # vcloud-dev), and without a fixed priority the result would not be reproducible.
      test 'resolve prefers the first configured tree when the same name exists in several trees' do
        duplicate = create_concept(@region_tree, ['Testland'])

        stub_geo_scope_feature(resolution_trees: [@region_tree.name, @admin_tree.name], geo_region_trees: [])

        assert_equal duplicate.id, DataCycleCore::Mcp::GeoScope.resolve('Testland').anchor.id

        stub_geo_scope_feature(resolution_trees: [@admin_tree.name, @region_tree.name], geo_region_trees: [@region_tree.name])

        assert_equal @land.id, DataCycleCore::Mcp::GeoScope.resolve('Testland').anchor.id
      end

      # A tree name is not unique in the database ("Kulinarisches Erbe" exists twice in vcloud-dev).
      # find_by took an arbitrary one of them -- which one was decided by the query plan, so the
      # resolution hung on exactly the chance the fixed stage and tree order rules out.
      test 'resolve searches all trees sharing the configured name' do
        shared_name = SecureRandom.hex(10)
        empty_tree = DataCycleCore::ConceptScheme.create!(name: shared_name, external_system_id: DataCycleCore::ExternalSystem.first.id)
        filled_tree = DataCycleCore::ConceptScheme.create!(name: shared_name, external_system_id: DataCycleCore::ExternalSystem.first.id)
        anchor = create_concept(filled_tree, ['Doppelort'])

        stub_geo_scope_feature(resolution_trees: [shared_name], geo_region_trees: [])
        scope = DataCycleCore::Mcp::GeoScope.resolve('Doppelort')

        assert_not_nil scope, 'the anchor lives in the second tree of the same name and must still be found'
        assert_equal anchor.id, scope.anchor.id
        assert_equal filled_tree.id, scope.concept_scheme.id
        assert_not_equal empty_tree.id, scope.concept_scheme.id
      end

      test 'stage 1 matches contents classified anywhere in the resolved subtree' do
        thing = create_lodging(classifications: [@municipality])

        scope = DataCycleCore::Mcp::GeoScope.resolve('Testland')

        assert_includes ids(scope), thing.id
        assert_equal :classification, stage_of(scope, thing)
      end

      # Stage 2 resolves by polygon containment, not by name equality -- in vcloud-dev no
      # geo_regions concept carries the federal state's name, yet 22 lie inside its polygon.
      test 'stage 2 resolves geo region concepts by polygon containment, not by name' do
        scope = DataCycleCore::Mcp::GeoScope.resolve('Testland')
        resolved = scope.send(:geo_region_concept_ids)

        assert_includes resolved, @region_inside.id
        assert_not_includes resolved, @region_outside.id
      end

      test 'stage 2 catches contents without any classification in the resolution tree' do
        inside = create_lodging(classifications: [@region_inside])
        outside = create_lodging(classifications: [@region_outside])

        scope = DataCycleCore::Mcp::GeoScope.resolve('Testland')

        assert_includes ids(scope), inside.id
        assert_not_includes ids(scope), outside.id
      end

      # The precedence: an existing assignment in the resolution tree decides, even when it does NOT
      # match the place. Otherwise the weaker source would override an explicit assignment.
      test 'a classification outside the place blocks the lower stages for that content' do
        other_land = create_concept(@admin_tree, ['Anderesland'])
        thing = create_lodging(classifications: [other_land, @region_inside], locality: 'Testdorf')

        scope = DataCycleCore::Mcp::GeoScope.resolve('Testland')

        assert_not_includes ids(scope), thing.id
      end

      test 'stage 3 matches address_locality against the subtree concept names with prefixes stripped' do
        thing = create_lodging(locality: 'Testdorf')

        scope = DataCycleCore::Mcp::GeoScope.resolve('Testland')

        assert_includes scope.send(:localities), 'Testdorf'
        assert_includes ids(scope), thing.id
        assert_equal :address, stage_of(scope, thing)
      end

      test 'stage 3 matches the configured postal code pattern for the resolved place' do
        thing = create_lodging(postal_code: '1234')

        stub_geo_scope_feature(resolution_trees: [@admin_tree.name], geo_region_trees: [@region_tree.name], postal_code_patterns: { 'Testland' => '^12[0-9]{2}$' }, locality_prefixes: ['Gemeinde'])

        assert_includes ids(DataCycleCore::Mcp::GeoScope.resolve('Testland')), thing.id

        stub_geo_scope_feature(resolution_trees: [@admin_tree.name], geo_region_trees: [@region_tree.name], locality_prefixes: ['Gemeinde'])

        assert_not_includes ids(DataCycleCore::Mcp::GeoScope.resolve('Testland')), thing.id
      end

      # The regression test for the bug that surfaced during verification against vcloud-dev: for a
      # municipality NO region polygon lies inside the place, so geo_region_concept_ids is empty. Were
      # the stage to gate anyway, the cascade would lose every content that is findable only through
      # its address and belongs to some (coarser) region -- measured 0 instead of 7 accommodations in
      # Gemeinde Egg.
      test 'an unresolvable geo region stage does not block the address stage' do
        thing = create_lodging(classifications: [@region_inside], locality: 'Testdorf')

        scope = DataCycleCore::Mcp::GeoScope.resolve('Gemeinde Testdorf')

        assert_empty scope.send(:geo_region_concept_ids)
        assert_includes ids(scope), thing.id
        assert_equal :address, stage_of(scope, thing)
      end

      # The stages are formulated disjointly so that coverage adds up to the total hit count --
      # otherwise the diagnostics could not be reconciled with the reported number.
      test 'coverage is disjoint and sums up to the total count' do
        create_lodging(classifications: [@municipality])
        create_lodging(classifications: [@region_inside])
        create_lodging(locality: 'Testdorf')

        scope = DataCycleCore::Mcp::GeoScope.resolve('Testland')
        filtered = scope.apply(base_query)

        assert_equal filtered.count, scope.coverage(filtered).values.sum
      end

      test 'to_h reports which stages resolved for the place' do
        stub_geo_scope_feature(resolution_trees: [@admin_tree.name], geo_region_trees: [])

        stages = DataCycleCore::Mcp::GeoScope.resolve('Testland').to_h[:stages].index_by { |s| s[:stage] }

        assert stages[:classification][:resolved]
        assert_not stages[:geo_regions][:resolved]
        assert stages[:address][:resolved]
      end

      private

      def base_query
        DataCycleCore::Filter::Search.new(locale: ['de']).template_names([TEMPLATE_NAME])
      end

      # The coverage of ONE content: the suite creates further articles in the same database, so
      # absolute per-stage counts would depend on them.
      def stage_of(scope, thing)
        scope.coverage(base_query.where(id: thing.id)).find { |_stage, count| count.positive? }&.first
      end

      def ids(scope)
        scope.apply(base_query).query.reorder(nil).pluck(:id)
      end

      def create_concept_scheme
        DataCycleCore::ConceptScheme.create!(name: SecureRandom.hex(10), external_system_id: DataCycleCore::ExternalSystem.first.id)
      end

      # Through ConceptScheme#insert_all_concepts_by_path rather than creating concept rows by hand:
      # concept_paths(_transitive) are built by trigger from concepts/concept_links, and a concept
      # inserted without its link has no path, so the subtree filter then found nothing.
      def create_concept(concept_scheme, path, polygon: nil)
        concept_scheme.insert_all_concepts_by_path([{ path: }])
        concept = DataCycleCore::Concept.by_full_paths("#{concept_scheme.name} > #{path.join(' > ')}").first

        if polygon
          DataCycleCore::ConceptPolygon.create!(
            concept_id: concept.id,
            geom: "SRID=4326;#{polygon}",
            geom_simple: "SRID=4326;#{polygon}"
          )
        end

        concept
      end

      # address deliberately lands in metadata and not in the translations -- that is where GeoScope
      # reads it, and where it sits in the real data too.
      def create_lodging(classifications: [], locality: nil, postal_code: nil)
        thing = DataCycleCore::Thing.create!(
          template_name: TEMPLATE_NAME,
          metadata: { 'address' => { 'address_locality' => locality, 'postal_code' => postal_code }.compact }
        )

        # Filter::Search#with_locale filters through an EXISTS on thing_translations -- without a
        # translation in the queried locale the content is invisible to EVERY filter.
        DataCycleCore::Thing::Translation.create!(thing_id: thing.id, locale: 'de', content: { 'name' => "geo scope test #{thing.id}" })

        classifications.each do |concept|
          DataCycleCore::ConceptContent.create!(content_data_id: thing.id, concept_id: concept.id, relation: 'geo_scope_test')
        end

        thing
      end
    end
  end
end
