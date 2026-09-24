# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # FilterSteps exists to pin the APPLICATION ORDER of the search_contents filters in one place --
    # the class comment gives the functional reasons for it (template_names before the facets, place
    # before near and the attributes). Until now that was precisely the class's one unproven promise:
    # the integration test checks the steps per filter kind, not their order relative to one another.
    # A reordering -- when slotting in a new filter, say -- would therefore have passed, and it is
    # not visible in the result but only in the runtime and in the order of the explain lines.
    #
    # Without a database: to_a returns [label, detail, lambda], and the lambdas are run against a
    # fake search that records the scopes called.
    class FilterStepsTest < ActiveSupport::TestCase
      # Accepts every scope call, remembers it and returns itself -- which lets a chain of steps be
      # folded as against a real Filter::Search.
      class FakeSearch
        attr_reader :calls

        def initialize = @calls = []

        def method_missing(name, *args)
          @calls << [name, args]
          self
        end

        def respond_to_missing?(_name, _include_private = false) = true
      end

      # A call in which EVERY filter is set -- only then is their relative order observable at all.
      def all_filters
        {
          query: 'Suchbegriff',
          template_names: ['Artikel'],
          exclude_classification_alias_ids: ['11111111-1111-1111-1111-111111111111'],
          attributes: [{ attribute: 'odta:length', in: { max: 15_000 } }],
          schedule: { from: '2026-08-01' },
          place: 'Testland',
          near: { lat: 47.5, lon: 10.5, radius_km: 5 },
          has_relations: ['image'],
          missing_relations: ['video']
        }.with_indifferent_access
      end

      def labels(steps) = steps.map(&:first)

      def build(arguments, groups: [], place_scope: nil)
        DataCycleCore::Mcp::FilterSteps.new(arguments:, groups:, place_scope:).to_a
      end

      # A double for the resolved place: FilterSteps reads only anchor.internal_name (for the explain
      # detail) and calls #apply -- the cascade itself is checked in GeoScopeTest.
      def place_scope_double
        anchor = Struct.new(:internal_name).new('Testland')
        Struct.new(:anchor) {
          def apply(search) = search.place_cascade
        }.new(anchor)
      end

      test 'the steps follow the documented order, whichever order the arguments come in' do
        steps = build(all_filters, groups: [['a']], place_scope: place_scope_double)

        assert_equal(
          ['query', 'template_names', 'classification_group', 'excluded_classifications',
           'attributes', 'schedule', 'place', 'near', 'has_relations', 'missing_relations'],
          labels(steps)
        )
      end

      # The two promises from the class comment individually, so a failure names WHICH ordering
      # decision has been overturned -- and not merely that the overall list looks different.
      test 'template_names is applied before the classification facets' do
        steps = labels(build(all_filters, groups: [['a']]))

        assert_operator steps.index('template_names'), :<, steps.index('classification_group')
      end

      test 'place is applied before near and before the attribute filters' do
        steps = labels(build(all_filters, place_scope: place_scope_double))

        assert_operator steps.index('place'), :<, steps.index('near')
        assert_operator steps.index('attributes'), :<, steps.index('near')
      end

      # The caller (Tools::SearchContents#apply_filters) folds the list unconditionally -- a filter
      # that was not requested MUST therefore yield no step, or a scope would run along with an empty
      # argument and additionally stand as an explain line of its own in the response.
      test 'an empty call produces no steps at all' do
        assert_empty build({}.with_indifferent_access)
      end

      test 'blank and empty filter values produce no step' do
        arguments = {
          query: '', template_names: [nil, ''], exclude_classification_alias_ids: [],
          attributes: [], schedule: {}, near: {}, has_relations: [], missing_relations: []
        }.with_indifferent_access

        assert_empty build(arguments)
      end

      # An unresolvable place name yields place_scope = nil and therefore no step: the hit count is
      # then the unfiltered set, marked through applied_filters.place.resolved.
      test 'an unresolvable place adds no step' do
        assert_not_includes labels(build(all_filters.merge('place' => 'Nirgendwo'), place_scope: nil)), 'place'
      end

      # Facet groups and relations are unfolded into one step each, so the explain log stays at one
      # line per condition.
      test 'each classification group becomes its own numbered step' do
        steps = build({}.with_indifferent_access, groups: [['a'], ['b'], ['c']])

        assert_equal ['classification_group'] * 3, labels(steps)
        assert_equal ['1/3', '2/3', '3/3'], steps.pluck(1)
      end

      test 'each relation name becomes its own step, dependencies before absences' do
        steps = build({ has_relations: ['image', 'video'], missing_relations: ['audio'] }.with_indifferent_access)

        assert_equal([['has_relations', 'image'], ['has_relations', 'video'], ['missing_relations', 'audio']],
                     steps.map { |label, detail, _| [label, detail] })
      end

      # ---- what the lambdas actually call -------------------------------------------------

      def applied(arguments, **)
        build(arguments, **).reduce(FakeSearch.new) { |search, (_l, _d, apply)| apply.call(search) }.calls
      end

      # FakeSearch answers every name, so the two tests below pin which scope is selected but not
      # that it exists - Redmine #41458 renamed all four and the suite stayed green while
      # apply_classification raised NoMethodError against a real Filter::Search.
      test 'every scope the subtree mapping can select exists on Filter::Search' do
        called = applied(
          { classification_alias_ids: ['a'], exclude_classification_alias_ids: ['b'], include_subtree: true }.with_indifferent_access,
          groups: [['a']]
        ).map(&:first) + applied(
          { classification_alias_ids: ['a'], exclude_classification_alias_ids: ['b'], include_subtree: false }.with_indifferent_access,
          groups: [['a']]
        ).map(&:first)

        assert_equal 4, called.uniq.size
        called.uniq.each { |scope| assert_respond_to DataCycleCore::Filter::Search.new, scope }
      end

      # include_subtree maps the include/exclude x subtree/exact matrix onto four scopes; the schema
      # deliberately holds only a boolean for it, so the mapping has to be checked.
      test 'include_subtree selects the subtree scopes, and defaults to on' do
        arguments = { classification_alias_ids: ['a'], exclude_classification_alias_ids: ['b'] }.with_indifferent_access
        called = applied(arguments.merge('include_subtree' => nil), groups: [['a']]).map(&:first)

        assert_equal [:concept_ids_with_subtree, :not_concept_ids_with_subtree], called
      end

      test 'include_subtree false selects the exact scopes' do
        arguments = { exclude_classification_alias_ids: ['b'], include_subtree: false }.with_indifferent_access
        called = applied(arguments, groups: [['a']]).map(&:first)

        assert_equal [:concept_ids_without_subtree, :not_concept_ids_without_subtree], called
      end

      # The default stands there as a class method because two sides need it: FilterSteps applies it,
      # FilterDescription reports it (Tools::SearchContents passes it there). Written twice in the
      # code, applied_filters could state "include_subtree: true" while filtering happened without the
      # subtree -- not recognisable from the hit count alone.
      test 'the reported subtree mode is read from the same rule the application uses' do
        {
          {} => true, { include_subtree: nil } => true, { include_subtree: true } => true,
          { include_subtree: false } => false
        }.each do |arguments, expected|
          arguments = arguments.with_indifferent_access
          reported = DataCycleCore::Mcp::FilterSteps.include_subtree?(arguments)

          assert_equal expected, reported, "#{arguments.inspect} was reported as include_subtree: #{reported}"

          applied = applied(arguments.merge('exclude_classification_alias_ids' => ['b'])).map(&:first)

          assert_equal [expected ? :not_concept_ids_with_subtree : :not_concept_ids_without_subtree],
                       applied, "#{arguments.inspect} was applied against the other scope than it reports"
        end
      end

      # On a text search, sorting is by relevance (as in the REST API) -- without that the search
      # would keep its sort_default order and the most relevant hits would not be on top.
      test 'a query both filters and re-sorts by relevance' do
        assert_equal [[:fulltext_search, ['Alpha']], [:sort_fulltext_search, ['DESC', 'Alpha']]],
                     applied({ query: 'Alpha' }.with_indifferent_access)
      end

      # Regression test: near was read through a dig on the OUTER argument hash. When near arrived
      # with string keys inside a symbol-keyed hash, lon/lat/distance were silently nil --
      # geo_radius ran with empty coordinates, the radius filter was ineffective, and applied_filters
      # still reported near as applied.
      test 'near is read regardless of how the argument hash is keyed' do
        expected = { 'lon' => 10.5, 'lat' => 47.5, 'distance' => 5, 'unit' => 'km' }

        [{ near: { 'lat' => 47.5, 'lon' => 10.5, 'radius_km' => 5 } },
         { near: { lat: 47.5, lon: 10.5, radius_km: 5 } },
         { 'near' => { 'lat' => 47.5, 'lon' => 10.5, 'radius_km' => 5 } }.with_indifferent_access].each do |arguments|
          assert_equal [[:geo_radius, [expected]]], applied(arguments),
                       "near was not read from #{arguments.class} with #{arguments[:near].keys.first.class} keys"
        end
      end
    end
  end
end
