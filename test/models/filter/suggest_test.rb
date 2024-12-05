# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SuggestTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      tags = DataCycleCore::Concept.for_tree('Tags').limit(1).pluck(:classification_id)
      DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Anfang 1', internal_name: 'Ende', tags: })
      DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Anfang 2', internal_name: 'Ende', tags: })
      DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Ende', internal_name: 'Anfang', tags: })
      DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Überschrift', internal_name: 'Untertitel Anfang Ende' })
    end

    test 'suggest_by_weight with all weights finds all articles' do
      assert_equal(4, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Anfang').count)
      assert_equal(4, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Ende').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Überschrift').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Untertitel').count)
    end

    test 'suggest_by_weight with A weights finds correct articles' do
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Anfang', ['de'], 10, 'A').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Ende', ['de'], 10, 'A').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Überschrift', ['de'], 10, 'A').count)
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Untertitel', ['de'], 10, 'A').count)
    end

    test 'suggest_by_weight with B weights finds correct articles' do
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Anfang', ['de'], 10, 'B').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Ende', ['de'], 10, 'B').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Ueberschrift', ['de'], 10, 'B').count)
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Untertitel', ['de'], 10, 'B').count)
    end

    test 'suggest_by_weight with C weights finds correct articles' do
      assert_equal(3, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('tag', ['de'], 10, 'C').count)
    end

    test 'suggest_by_weight with D weights finds correct articles' do
      assert_equal(4, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Anfang', ['de'], 10, 'D').count)
      assert_equal(4, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Ende', ['de'], 10, 'D').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Überschrift', ['de'], 10, 'D').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_weight('Untertitel', ['de'], 10, 'D').count)
    end

    test 'suggest_by_title finds correct articles' do
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_title('Anfang').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_title('Ende').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_title('Überschrift').count)
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_title('Untertitel').count)
      assert_equal(['Anfang 1', 'Anfang 2'].to_set, DataCycleCore::Filter::Search.new(locale: [:de]).typeahead_by_title('Anfang').to_set)
    end
  end
end
