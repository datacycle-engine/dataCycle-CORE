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
      create_content('Artikel', { name: 'HEADLINE 1', tags: get_concept_ids('Tags', ['Tag 3']) })
      create_content('Artikel', { name: 'HEADLINE 2', tags: get_concept_ids('Tags', ['Tag 2', 'Nested Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 3', tags: get_concept_ids('Tags', ['Tag 3', 'Tag 2']) })
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
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3', fields: 'dc:text' }).count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3', fields: 'dc:classification,dc:text' }).count)
    end

    test 'fulltext search restricted to indexed text attributes' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search('FFF').count)
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'FFF', fields: 'name,dc:slug,dc:classification' }).count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'FFF', fields: 'dc:text' }).count)
    end

    test 'fulltext search with nil specified weights' do
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search('Tag 3').count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3', fields: nil }).count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3', fields: '' }).count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search({ value: 'Tag 3' }).count)
    end

    # Canonical anchor for the rule that the dictionary is named inline rather than joined in
    # from pg_dict_mappings -- Filter::Common::Fulltext#search_vector_prefix_match carries the
    # reasoning. Joining it back returns exactly the same rows, only slower, so the assertions
    # above would all still pass and these are the only tests that would notice.
    test 'fulltext search names the dictionary inline instead of joining pg_dict_mappings' do
      sql = DataCycleCore::Filter::Search.new(locale: [:de]).fulltext_search('Tag 3').query.to_sql

      assert_includes(sql, "websearch_to_prefix_tsquery(get_dict('de')")
      assert_not_includes(sql, 'pg_dict_mappings')
    end

    test 'fulltext search matches each locale against its own dictionary' do
      sql = DataCycleCore::Filter::Search.new(locale: [:de, :en]).fulltext_search('Tag 3').query.to_sql

      ['de', 'en'].each do |locale|
        assert_includes(sql, "websearch_to_prefix_tsquery(get_dict('#{locale}')")
        assert_includes(sql, %("searches"."locale" = '#{locale}'))
      end
      assert_not_includes(sql, 'pg_dict_mappings')
    end

    test 'fulltext sorting names the dictionary inline' do
      sql = DataCycleCore::Filter::Search.new(locale: [:de]).sort_fulltext_search('DESC', 'Tag 3').query.to_sql

      assert_includes(sql, "websearch_to_prefix_tsquery(get_dict('de')")
      assert_not_includes(sql, 'pg_dict_mappings')
    end

    test 'mapping fulltext fields to tsquery weights' do
      assert_equal('', DataCycleCore::Filter::Search.fulltext_fields_to_weights(nil))
      assert_equal('AB', DataCycleCore::Filter::Search.fulltext_fields_to_weights('name, dc:slug'))
      assert_equal('D', DataCycleCore::Filter::Search.fulltext_fields_to_weights('dc:text'))
      assert_equal('A', DataCycleCore::Filter::Search.fulltext_fields_to_weights('name,name'))
      assert_equal('', DataCycleCore::Filter::Search.fulltext_fields_to_weights('name,dc:slug,dc:classification,dc:text'))
    end
  end
end
