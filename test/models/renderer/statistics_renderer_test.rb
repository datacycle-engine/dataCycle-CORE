# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StatisticsRendererTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @contents = []
      @tag = DataCycleCore::ClassificationAlias.for_tree('Tags').first.primary_classification
      5.times do |i|
        travel_to i.days.ago do
          @contents << DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: "Test Artikel #{i}", tags: [@tag.id] }, prevent_history: true)
        end
      end

      @contents << DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 6', tags: [@tag.id] }, prevent_history: true)
      @contents << DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 7', tags: [@tag.id] }, prevent_history: true)

      @query = DataCycleCore::StoredFilter.new.parameters_from_hash(
        [
          { with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Artikel'] } },
          { with_classification_aliases_and_treename: { treeLabel: 'Tags', aliases: [@tag.name] } }
        ]
      ).tap(&:save!).apply.query
    end

    test 'default statistics for dct:created with stored_filter' do
      renderer = DataCycleCore::ApiRenderer::StatisticsRenderer.new(query: @query, attribute: 'dct:created')
      json_data = JSON.parse(renderer.render(:json))

      assert_equal 7, json_data['data'].size

      @contents.each do |content|
        assert content.id.in?(json_data['data'].map(&:last))
      end
    end

    test 'statistics for dct:created with stored_filter and group_by day' do
      renderer = DataCycleCore::ApiRenderer::StatisticsRenderer.new(query: @query, attribute: 'dct:created', group_by: +'day')
      json_data = JSON.parse(renderer.render(:json))

      assert_equal 5, json_data['data'].size
      assert_equal 3, json_data['data'][4].last
      assert_equal 1, json_data['data'][3].last
      assert_equal 1, json_data['data'][2].last
      assert_equal 1, json_data['data'][1].last
      assert_equal 1, json_data['data'][0].last
    end

    test 'statistics for dct:created with stored_filter and group_by day and filter from date' do
      renderer = DataCycleCore::ApiRenderer::StatisticsRenderer.new(query: @query, attribute: 'dct:created', group_by: +'day', time: { in: { min: 2.days.ago.beginning_of_day.iso8601 } })
      json_data = JSON.parse(renderer.render(:json))

      assert_equal 3, json_data['data'].size
      assert_equal 3, json_data['data'][2].last
      assert_equal 1, json_data['data'][1].last
      assert_equal 1, json_data['data'][0].last
    end

    test 'statistics for dct:created with stored_filter and group_by day and filter to date' do
      renderer = DataCycleCore::ApiRenderer::StatisticsRenderer.new(query: @query, attribute: 'dct:created', group_by: +'day', time: { in: { max: 2.days.ago.beginning_of_day.iso8601 } })
      json_data = JSON.parse(renderer.render(:json))

      assert_equal 2, json_data['data'].size
      assert_equal 1, json_data['data'][1].last
      assert_equal 1, json_data['data'][0].last
    end

    test 'default statistics for dct:created with watch_list' do
      watch_list = DataCycleCore::WatchList.create(full_path: 'TEST1', api: true)
      watch_list.things.concat(@contents)

      renderer = DataCycleCore::ApiRenderer::StatisticsRenderer.new(query: watch_list.things, attribute: 'dct:created')
      json_data = JSON.parse(renderer.render(:json))

      assert_equal 7, json_data['data'].size

      @contents.each do |content|
        assert content.id.in?(json_data['data'].map(&:last))
      end
    end

    test 'statistics for dct:created with stored_filter and group_by day and data_format object' do
      renderer = DataCycleCore::ApiRenderer::StatisticsRenderer.new(query: @query, attribute: 'dct:created', group_by: +'day', data_format: +'object')
      json_data = JSON.parse(renderer.render(:json))

      assert_equal 5, json_data['data'].size
      assert_equal 3, json_data['data'][4]['y']
      assert_equal 1, json_data['data'][3]['y']
      assert_equal 1, json_data['data'][2]['y']
      assert_equal 1, json_data['data'][1]['y']
      assert_equal 1, json_data['data'][0]['y']
    end
  end
end
