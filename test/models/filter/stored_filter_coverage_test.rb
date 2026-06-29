# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Focused coverage for the mostly-pure helper methods on StoredFilter that are not
  # exercised by the integration/API suites: the filter (in)equality comparisons,
  # the select-option/builder helpers, the duplicate-search validator and the
  # private locale resolver. Named distinctly from StoredFilterTest to avoid a
  # parallel_tests test-class collision (same FQN + different body silently merges,
  # but a unique name is collision-proof regardless of distribution).
  class StoredFilterCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def subject = DataCycleCore::StoredFilter

    test 'api_v4_type returns the dynamic collection type' do
      assert_equal 'dc:DynamicCollection', subject.new.api_v4_type
    end

    test 'from_property_definition builds from an explicit stored_filter' do
      filter = subject.from_property_definition({ 'stored_filter' => [{ 't' => 'template_names', 'v' => 'Artikel' }] })

      assert_instance_of subject, filter
      assert_equal [{ 't' => 'template_names', 'v' => 'Artikel' }], filter.parameters
    end

    test 'from_property_definition builds from a template_name shorthand' do
      filter = subject.from_property_definition({ 'template_name' => 'Artikel' })

      assert_instance_of subject, filter
      assert_equal [{ 't' => 'template_names', 'v' => 'Artikel' }], filter.parameters
    end

    test 'from_property_definition rejects a non-hash definition' do
      assert_raises(ArgumentError) { subject.from_property_definition('not a hash') }
    end

    test 'from_property_definition rejects a hash without a known key' do
      assert_raises(ArgumentError) { subject.from_property_definition({ 'foo' => 'bar' }) }
    end

    test 'to_stored_filter builds a lightweight copy carrying the parameters' do
      original = subject.new(parameters: [{ 't' => 'template_names', 'v' => 'Artikel' }])
      copy = original.to_stored_filter

      assert_instance_of subject, copy
      assert_not_same original, copy
      assert_equal original.parameters, copy.parameters
    end

    test 'filter_type_equal? compares only the type-relevant keys' do
      filter = subject.new
      f1 = { 't' => 'x', 'c' => 'a', 'n' => 'N', 'q' => 'Q', 'v' => 1 }
      f2 = { 't' => 'x', 'c' => 'b', 'n' => 'N', 'q' => 'Q', 'v' => 2 }

      # value differences are ignored; context differences matter only when considered
      assert filter.filter_type_equal?(f1, f2, consider_context: false)
      assert_not filter.filter_type_equal?(f1, f2)
    end

    test 'filter_equal? recurses into union filters' do
      filter = subject.new
      inner = { 't' => 'classification_alias_ids', 'c' => 'a', 'n' => 'N', 'q' => 'Q', 'v' => ['id'] }
      union1 = { 't' => 'union', 'c' => 'a', 'n' => 'N', 'q' => 'Q', 'v' => [inner] }
      union2 = { 't' => 'union', 'c' => 'a', 'n' => 'N', 'q' => 'Q', 'v' => [inner.dup] }

      assert filter.filter_equal?(union1, union2)
      # differing nested size short-circuits to false
      assert_not filter.filter_equal?(union1, { 't' => 'union', 'c' => 'a', 'n' => 'N', 'q' => 'Q', 'v' => [] })
    end

    test 'to_select_option renders a select option for a named and an unnamed filter' do
      named = subject.new(name: 'My Filter').to_select_option

      assert_instance_of DataCycleCore::Filter::SelectOption, named
      assert_includes named.name, 'My Filter'

      unnamed = subject.new.to_select_option

      assert_includes unnamed.name, '__DELETED__'
    end

    test 'thing_ids resolves to an array of ids for an unsaved filter' do
      # a classification filter on a non-existent alias resolves to an empty, cheap query
      filter = subject.new(
        language: ['de'],
        parameters: [{ 't' => 'classification_alias_ids', 'm' => 'i', 'c' => 'a', 'n' => 'x',
                       'v' => ['00000000-0000-0000-0000-000000000000'] }]
      )

      assert_equal [], filter.thing_ids
    end

    test 'private locale resolves language to nil for blank or all' do
      assert_nil subject.new(language: nil).send(:locale)
      assert_nil subject.new(language: ['all']).send(:locale)
      assert_equal ['de'], subject.new(language: ['de']).send(:locale)
    end

    # --- validate_by_duplicate_search -------------------------------------------------

    # A minimal content stand-in exposing just the surface the validator touches.
    def content_double(warnings: nil)
      content = Object.new
      content.define_singleton_method(:properties_for) do |key|
        { 'name' => { 'type' => 'string' },
          'data_type' => { 'tree_label' => 'Inhaltstypen', 'default_value' => 'Artikel' } }[key]
      end
      # presence of #data_type drives the respond_to?(:data_type) branch in the validator
      content.define_singleton_method(:data_type) { 'Artikel' }
      content.define_singleton_method(:warnings) { warnings } if warnings
      content
    end

    # A self-returning stand-in for the StoredFilter the validator builds internally,
    # so the duplicate count is fully controlled (no fulltext index dependency).
    def filter_double(size)
      filter = Object.new
      filter.define_singleton_method(:readonly!) { nil }
      filter.define_singleton_method(:apply) { |**| filter }
      filter.define_singleton_method(:query) { filter }
      filter.define_singleton_method(:reorder) { |_| filter }
      filter.define_singleton_method(:size) { size }
      filter.define_singleton_method(:parameters) { [{ 't' => 'fulltext_search' }] }
      filter
    end

    test 'validate_by_duplicate_search returns empty for blank inputs and non-string keys' do
      assert_equal({}, subject.validate_by_duplicate_search(content_double, nil, 'name', nil, 'de'))
      assert_equal({}, subject.validate_by_duplicate_search(content_double, { 'name' => 'x' }, '', nil, 'de'))
      # primary_key present but its property type is not 'string'
      assert_equal({}, subject.validate_by_duplicate_search(content_double, { 'data_type' => 'x' }, 'data_type', nil, 'de'))
      # value at the primary key is blank
      assert_equal({}, subject.validate_by_duplicate_search(content_double, { 'name' => '' }, 'name', nil, 'de'))
    end

    test 'validate_by_duplicate_search returns empty when no duplicates are found' do
      subject.stub(:new, filter_double(0)) do
        assert_equal({}, subject.validate_by_duplicate_search(content_double, { 'name' => 'Foo' }, 'name', nil, 'de'))
      end
    end

    test 'validate_by_duplicate_search reports duplicates and adds a content warning' do
      added = []
      warnings = Object.new
      warnings.define_singleton_method(:add) { |*args| added << args }

      subject.stub(:new, filter_double(3)) do
        result = subject.validate_by_duplicate_search(content_double(warnings:), { 'name' => 'Foo' }, 'name', nil, 'de')

        assert_equal 3, result.dig(:duplicate_search, :count)
        assert_includes result.dig(:duplicate_search, :popup_text), '<p>'
        assert_equal [{ 't' => 'fulltext_search' }], result.dig(:duplicate_search, :filter_params)
      end

      assert_equal 1, added.size
      assert_equal 'name', added.first.first
    end
  end
end
