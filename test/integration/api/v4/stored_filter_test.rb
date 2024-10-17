# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class StoredFilterTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        # rubocop:disable Minitest/MultipleAssertions
        before(:all) do
          DataCycleCore::Thing.delete_all
          @routes = Engine.routes
          @test_content = DataCycleCore::DummyDataHelper.create_data('tour')
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        def add_fulltext_filter(string)
          DataCycleCore::StoredFilter.create(
            name: 'fulltext',
            user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
            language: ['de'],
            parameters: [{
              'n' => 'Suchbegriff',
              't' => 'fulltext_search',
              'v' => string
            }],
            sort_parameters: [{
              'v' => string,
              'm' => 'fulltext_search',
              'o' => 'DESC'
            }],
            api: true
          )
        end

        def add_relation_filter(string)
          image_filter = add_fulltext_filter(string)
          DataCycleCore::StoredFilter.create(
            name: 'fulltext',
            user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
            language: ['de'],
            parameters: [{
              'c' => 'd',
              'm' => 'i',
              'n' => 'Inhaltstypen',
              't' => 'classification_alias_ids',
              'v' => DataCycleCore::ClassificationAlias.where(name: 'POI').ids
            }, {
              'c' => 'a',
              'm' => 'i',
              'n' => 'test_filter',
              'q' => 'image',
              't' => 'relation_filter',
              'v' => image_filter.id
            }, {
              't' => 'order',
              'v' => 'things.boost DESC, things.updated_at DESC'
            }],
            api: true
          )
        end

        def all_things
          get api_v4_things_path(include: 'image,poi.image')
          response.parsed_body
        end

        test '/api/v4/endpoints/:uuid with a valid stored_filter slug' do
          poi_name = 'Test-POI'
          fulltext_filter = add_fulltext_filter(poi_name)
          get api_v4_stored_filter_path(id: fulltext_filter.slug, include: 'image,poi.image')

          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert(json_data.key?('links'))

          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_equal(1, poi.dig('image')&.size)
        end

        test '/api/v4/endpoints/:uuid with a valid fulltext stored_filter' do
          poi_name = 'Test-POI'
          fulltext_filter = add_fulltext_filter(poi_name)
          get api_v4_stored_filter_path(id: fulltext_filter.id, include: 'image,poi.image')

          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert(json_data.key?('links'))

          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_equal(1, poi.dig('image')&.size)
        end

        test '/api/v4/endpoints/:uuid with a valid fulltext stored_filter and restrict for classification_trees' do
          poi_name = 'Test-POI'
          fulltext_filter = add_fulltext_filter(poi_name)
          get api_v4_stored_filter_path(id: fulltext_filter.id)

          json_data = response.parsed_body
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_equal(1, poi.dig('dc:classification')&.size)

          # add whitelist to stored_filter
          tree1 = Array.wrap(DataCycleCore::ClassificationTreeLabel.find_by(name: 'Ländercodes').id)
          tree2 = Array.wrap(DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id)
          fulltext_filter.classification_tree_labels = tree2
          fulltext_filter.save

          get api_v4_stored_filter_path(id: fulltext_filter.id)
          json_data = response.parsed_body
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_nil(poi.dig('dc:classification'))

          # whitelist for in request
          get api_v4_stored_filter_path(id: fulltext_filter.id, classification_trees: tree1)
          json_data = response.parsed_body
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_equal(1, poi.dig('dc:classification')&.size)

          # directly whitlist in filter
          fulltext_filter.classification_tree_labels = tree1
          fulltext_filter.save

          get api_v4_stored_filter_path(id: fulltext_filter.id)
          json_data = response.parsed_body
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_equal(1, poi.dig('dc:classification')&.size)
        end

        test '/api/v4/endpoints/:uuid with a valid fulltext stored_filter and restrict for classification_trees in linked data' do
          tree1 = Array.wrap(DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltspools').id)
          tree2 = Array.wrap(DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id)
          poi_name = 'Test-POI'
          fulltext_filter = add_fulltext_filter(poi_name)

          get api_v4_stored_filter_path(id: fulltext_filter.id, include: 'image,poi.image')
          json_data = response.parsed_body
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_equal(2, poi.dig('image', 0, 'dc:classification')&.size)

          fulltext_filter.classification_tree_labels = tree1
          fulltext_filter.save
          get api_v4_stored_filter_path(id: fulltext_filter.id, include: 'image,poi.image')
          json_data = response.parsed_body
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_equal(1, poi.dig('image', 0, 'dc:classification')&.size)

          fulltext_filter.classification_tree_labels = tree2
          fulltext_filter.save
          get api_v4_stored_filter_path(id: fulltext_filter.id, include: 'image,poi.image')
          json_data = response.parsed_body
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_nil(poi.dig('image', 0, 'dc:classification')&.size)
        end

        test '/api/v4/endpoints/:uuid with a valid stored_filter and filter for linked' do
          height_filter = DataCycleCore::StoredFilter.create(
            name: 'height < 1000px',
            user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
            language: ['de'],
            parameters: [{
              'c' => 'a',
              'm' => 'i',
              'n' => 'height',
              'q' => 'numeric',
              't' => 'advanced_attributes',
              'v' => { 'max' => '1000', 'min' => '' }
            }, {
              't' => 'order',
              'v' => 'things.boost DESC, things.updated_at DESC'
            }],
            api: false
          )
          poi_name = 'Test-POI'
          fulltext_filter = add_fulltext_filter(poi_name)
          fulltext_filter.linked_stored_filter_id = height_filter.id
          fulltext_filter.save

          get api_v4_stored_filter_path(id: fulltext_filter.id, include: 'image,poi.image')

          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert(json_data.key?('links'))

          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }

          assert_nil(poi.dig('image'))
        end

        test '/api/v4/endpoints/:uuid with relation_filter, finds one POI with one suitable image' do
          relation_filter = add_relation_filter('headline')
          get api_v4_stored_filter_path(id: relation_filter.id, include: 'image,poi.image')

          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == 'Test-POI' }

          assert_equal(1, poi.dig('image')&.size)
        end

        test '/api/v4/endpoints/:uuid with relation_filter, all POIs filtered out because no valid image found' do
          relation_filter = add_relation_filter('something_not_present')
          get api_v4_stored_filter_path(id: relation_filter.id, include: 'image,poi.image')

          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert_equal(0, json_data['@graph'].size)
          assert_equal(0, json_data['meta']['total'].to_i)
        end

        test '/api/v4/endpoints/:uuid renders correct links' do
          filter = DataCycleCore::StoredFilter.create(
            name: 'dummy',
            user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
            language: ['de'],
            api: true
          )
          get api_v4_stored_filter_path(id: filter.id, page: { number: 1, size: 1 })

          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          uri = Addressable::URI.parse(json_data.dig('links', 'next'))

          assert_equal(api_v4_stored_filter_path(id: filter.id, page: { number: 2, size: 1 }), "#{uri.path}?#{uri.query}")
        end
        # rubocop:enable Minitest/MultipleAssertions
      end
    end
  end
end
