# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TsQueryFulltextSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @ts_query_before_state = DataCycleCore.features[:ts_query_fulltext_search].deep_dup
      DataCycleCore.features[:ts_query_fulltext_search][:enabled] = true
      Feature::TsQueryFulltextSearch.reload
      @things = DataCycleCore::Thing.count
      create_content('Artikel', { name: 'AAA' })
      create_content('Artikel', { name: 'HEADLINE 1', tags: get_classification_ids('Tags', ['Tag 3']) })
      create_content('Artikel', { name: 'HEADLINE 2', tags: get_classification_ids('Tags', ['Tag 2', 'Nested Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 3', tags: get_classification_ids('Tags', ['Tag 3', 'Tag 2']) })
      create_content('Örtlichkeit', { name: 'PLACE 1' })
      create_content('Event', { name: 'DDD', overlay: [{ name: 'EEE' }], sub_event: [{ name: 'FFF' }] })
    end

    after(:all) do
      DataCycleCore.features = DataCycleCore.features.except(:ts_query_fulltext_search)
        .merge({ ts_query_fulltext_search: @ts_query_before_state })
      Feature::TsQueryFulltextSearch.reload
    end

    test 'fulltext search with specified weights' do
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search('Tag 3').count)
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3', fields: 'name' }).count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3', fields: 'dc:classification' }).count)
    end

    test 'fulltext search with nil specified weights' do
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search('Tag 3').count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3', fields: nil }).count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3', fields: '' }).count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3' }).count)
    end
  end
end
