# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the AdvancedFilterByType ability segment - the include? dispatch and
  # the per-advanced-type matchers, which are pure logic over the allowed_types hash and
  # the filter data hash (no DB / ability context needed except for to_restrictions).
  class AdvancedFilterByTypeSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def segment(allowed_types)
      DataCycleCore::Abilities::Segments::AdvancedFilterByType.new(:things, allowed_types)
    end

    # Wraps the segment's #include? predicate (named separately so the
    # Minitest/AssertIncludes cop does not mistake it for collection membership).
    def allows?(seg, type, data = {})
      seg.include?(nil, nil, type, data)
    end

    test 'include? short-circuits on a nil type and on a type outside allowed_types' do
      seg = segment({ 'foo' => nil })

      assert allows?(seg, nil)            # nil type -> always allowed
      assert_not allows?(seg, 'unknown')  # type not in allowed_types -> denied
    end

    test 'geo_filter_type matches radius, classification and falls back to false' do
      seg = segment({ 'geo_filter' => { 'geo_radius' => true, 'geo_within_classification' => ['Tirol'] } })

      assert allows?(seg, 'geo_filter', { data: { advancedType: 'geo_radius' } })
      assert allows?(seg, 'geo_filter', { data: { advancedType: 'geo_within_classification', name: 'Tirol' } })
      assert_not allows?(seg, 'geo_filter', { data: { advancedType: 'geo_within_classification', name: 'Wien' } })
      assert_not allows?(seg, 'geo_filter', { data: { advancedType: 'something_else' } })
    end

    test 'default_type allows nil and all/true configs and otherwise matches the advancedType' do
      seg = segment({ 'untyped' => nil, 'wildcard' => 'all', 'listed' => ['x'] })

      assert allows?(seg, 'untyped', { data: {} })   # key present, no restriction -> allowed
      assert allows?(seg, 'wildcard', { data: {} })  # 'all' -> allowed
      assert allows?(seg, 'listed', { data: { advancedType: 'x' } })
      assert_not allows?(seg, 'listed', { data: { advancedType: 'y' } })
    end

    test 'name-keyed matchers dispatch through default_type with the :name key' do
      seg = segment({
        'classification_alias_ids' => ['n1'],
        'advanced_attributes' => ['n2'],
        'boolean' => ['n3']
      })

      assert allows?(seg, 'classification_alias_ids', { data: { name: 'n1' } })
      assert allows?(seg, 'advanced_attributes', { data: { name: 'n2' } })
      assert allows?(seg, 'boolean', { data: { name: 'n3' } })
      assert_not allows?(seg, 'boolean', { data: { name: 'other' } })
    end

    test 'to_proc returns a callable delegating to include?' do
      callable = segment({ 'foo' => nil }).to_proc

      assert callable.call(nil, nil, nil)
    end

    test 'to_restrictions returns nil for blank allowed_types and a value otherwise' do
      assert_nil segment({}).send(:to_restrictions)

      seg = segment({ 'geo_filter' => ['x'] })
      ability = Object.new
      ability.define_singleton_method(:user) { nil } # so #locale resolves to the default ui locale
      seg.ability = ability

      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end
