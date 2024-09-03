# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AggregateFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @things_count = DataCycleCore::Thing.count
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 1' })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 2' })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 3' })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 4' })
      c1 = create_content('Artikel', { name: 'AGGREGATE 1' })
      c1.update(aggregate_type: 'aggregate')
      c2 = create_content('Artikel', { name: 'BELONGS_TO_AGGREGATE 1' })
      c2.update(aggregate_type: 'belongs_to_aggregate')
    end

    test 'filter contents based on aggregate_type -> default' do
      items = DataCycleCore::Filter::Search.new(:de).aggregate_filter('default')
      assert_equal(@things_count + 4, items.count)
    end

    test 'filter contents based on aggregate_type -> aggregate' do
      items = DataCycleCore::Filter::Search.new(:de).aggregate_filter('aggregate')
      assert_equal(1, items.count)
    end

    test 'filter contents based on aggregate_type -> belongs_to_aggregate' do
      items = DataCycleCore::Filter::Search.new(:de).aggregate_filter('belongs_to_aggregate')
      assert_equal(1, items.count)
    end

    test 'filter contents based on aggregate_type -> default, aggregate' do
      items = DataCycleCore::Filter::Search.new(:de).aggregate_filter(['default', 'aggregate'])
      assert_equal(@things_count + 4 + 1, items.count)
    end

    test 'filter contents based on not aggregate_type -> default' do
      items = DataCycleCore::Filter::Search.new(:de).not_aggregate_filter('default')
      assert_equal(2, items.count)
    end

    test 'filter contents based on not aggregate_type -> aggregate' do
      items = DataCycleCore::Filter::Search.new(:de).not_aggregate_filter('aggregate')
      assert_equal(@things_count + 4 + 1, items.count)
    end

    test 'filter contents based on not aggregate_type -> belongs_to_aggregate' do
      items = DataCycleCore::Filter::Search.new(:de).not_aggregate_filter('belongs_to_aggregate')
      assert_equal(@things_count + 4 + 1, items.count)
    end
  end
end
