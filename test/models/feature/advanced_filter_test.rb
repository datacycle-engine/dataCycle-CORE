# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FeatureAdvancedFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Feature::AdvancedFilter

    def feature
      @feature ||= SUBJECT.new
    end

    test 'filter_requires_n_for_comparison? detects filters whose value lives in n' do
      assert feature.filter_requires_n_for_comparison?({ 't' => 'classification_alias_ids' })
      assert feature.filter_requires_n_for_comparison?({ 't' => 'geo_filter', 'q' => 'geo_within_classification' })
      assert_not feature.filter_requires_n_for_comparison?({ 't' => 'fulltext_search' })
    end

    test 'relation_filter_inv builds tuples for truthy relations only' do
      result = feature.relation_filter_inv(:de, { 'work' => { 'attribute' => 'translation_of_work' }, 'skip' => false })

      assert_equal 1, result.size
      assert_equal 'relation_filter_inv', result.first[1]
      assert_equal 'translation_of_work', result.first[2].dig(:data, :advancedType)
    end

    test 'geo_filter returns an empty array for non-hash values' do
      assert_empty feature.geo_filter(:de, 'not-a-hash')
    end

    test 'geo_filter handles array and scalar entries' do
      result = feature.geo_filter(:de, { 'perimeter_search' => ['poi'], 'geo_radius' => true })

      types = result.pluck(1).uniq

      assert_equal ['geo_filter'], types
      assert_equal 2, result.size
    end

    test 'date_range handles all, hash, array and unknown configurations' do
      assert_equal 2, feature.date_range(:de, 'all').size
      assert_equal(['created_at'], feature.date_range(:de, { created_at: true }).map { |r| r[2].dig(:data, :name).to_s })
      assert_equal(['updated_at'], feature.date_range(:de, ['updated_at']).map { |r| r[2].dig(:data, :name) })
      assert_empty feature.date_range(:de, 'something-else')
    end

    test 'boolean skips entries whose dependency feature is disabled' do
      result = feature.boolean(:de, [
                                 { 'missing_dependency' => { 'depends_on' => 'DataCycleCore::DoesNotExist' } },
                                 { 'plain_flag' => {} }
                               ])

      assert_equal(['plain_flag'], result.map { |r| r[2].dig(:data, :name) })
    end

    test 'related_through_attribute builds tuples for truthy values' do
      result = feature.related_through_attribute(:de, { 'rel' => { 'attribute' => 'attr' }, 'skip' => nil })

      assert_equal 1, result.size
      assert_equal 'related_through_attribute', result.first[1]
      assert_equal 'attr', result.first[2].dig(:data, :advancedType)
    end

    test 'offer_period builds tuples for truthy values' do
      result = feature.offer_period(:de, { 'offer' => true, 'skip' => nil })

      assert_equal 1, result.size
      assert_equal 'offer_period', result.first[1]
    end

    test 'advanced_attribute_classification_tree_label reads from configuration' do
      assert_nil SUBJECT.advanced_attribute_classification_tree_label('does-not-exist')
    end

    test 'schedule_filter_exceptions_string joins translated exceptions' do
      assert_kind_of String, SUBJECT.schedule_filter_exceptions_string(:de)
    end

    test 'relation_filter_restrictions returns the configured filter for hash entries' do
      config = { 'relation_filter' => { 'work' => { 'filter' => { 'a' => 1 } } } }.with_indifferent_access

      SUBJECT.stub(:configuration, config) do
        assert_equal({ 'a' => 1 }, SUBJECT.relation_filter_restrictions('relation_filter', 'work'))
        assert_nil SUBJECT.relation_filter_restrictions('relation_filter', 'unknown')
      end
    end

    test 'graph_filter_restrictions returns the configured filter for hash entries' do
      config = { 'graph_filter' => { 'items_linked_to' => { 'filter' => { 'b' => 2 } } } }.with_indifferent_access

      SUBJECT.stub(:configuration, config) do
        assert_equal({ 'b' => 2 }, feature.graph_filter_restrictions('graph_filter', 'items_linked_to'))
        assert_nil feature.graph_filter_restrictions('graph_filter', 'unknown')
      end
    end

    test 'graph_filter_relations groups relations by template name' do
      assert_kind_of Hash, SUBJECT.graph_filter_relations
    end

    test 'selected_graph_filter_relations returns nothing without relations' do
      assert_empty SUBJECT.selected_graph_filter_relations(relations: nil)
    end

    test 'selected_graph_filter_relations groups the requested relations' do
      assert_kind_of Hash, SUBJECT.selected_graph_filter_relations(relations: ['translation_of_work'])
    end

    test 'all_filters_with_advanced_type collects advanced types and memoizes the result' do
      advanced_filter = SUBJECT.new

      result = SUBJECT.stub(:enabled?, true) do
        SUBJECT.stub(:configuration, { 'date_range' => 'all' }) do
          advanced_filter.all_filters_with_advanced_type
          advanced_filter.all_filters_with_advanced_type # second call hits the memoized return
        end
      end

      assert_kind_of Array, result
    end

    test 'available_visible_filters builds the configured filters allowed for the user' do
      user = Object.new
      user.define_singleton_method(:ui_locale) { :de }
      user.define_singleton_method(:can?) { |*_args| true }

      result = SUBJECT.stub(:enabled?, true) do
        feature.available_visible_filters(user, 'show', [{ 'date_range' => 'all' }])
      end

      assert_kind_of Array, result
      assert_equal 2, result.size
    end

    test 'graph_filter returns [] for non-hash values and when there are no content links' do
      assert_empty feature.graph_filter(:de, 'not-a-hash')
      assert_empty feature.graph_filter(:de, { 'items_linked_to' => true })
    end
  end
end
