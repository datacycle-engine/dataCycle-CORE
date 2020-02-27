# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class StoredFilterTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @test_content = DataCycleCore::DummyDataHelper.create_data('tour')
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
            }, {
              't' => 'order',
              'v' => "things.boost * (8 * similarity(searches.classification_string, '%#{string}%') + 4 * similarity(searches.headline, '%#{string}%') + 2 * ts_rank_cd(searches.words, plainto_tsquery('simple', '#{string}'),16) + 1 * similarity(searches.full_text, '%#{string}%')) DESC NULLS LAST, things.updated_at DESC"
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
          JSON.parse(response.body)
        end

        test '/api/v4/endpoints/:uuid with a valid fulltext stored_filter' do
          poi_name = 'Test-POI'
          fulltext_filter = add_fulltext_filter(poi_name)
          get api_v4_stored_filter_path(id: fulltext_filter.id, include: 'image,poi.image')

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }
          assert_equal(1, poi.dig('image')&.size)
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

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          poi = json_data.dig('@graph').detect { |i| i.dig('name') == poi_name }
          assert_nil(poi.dig('image'))
        end

        test '/api/v4/endpoints/:uuid with relation_filter, finds one POI with one suitable image' do
          relation_filter = add_relation_filter('headline')
          get api_v4_stored_filter_path(id: relation_filter.id, include: 'image,poi.image')
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)

          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          poi = json_data.dig('@graph').detect { |i| i.dig('name') == 'Test-POI' }
          assert_equal(1, poi.dig('image')&.size)
        end

        test '/api/v4/endpoints/:uuid with relation_filter, all POIs filtered out because no valid image found' do
          relation_filter = add_relation_filter('something_not_present')
          get api_v4_stored_filter_path(id: relation_filter.id, include: 'image,poi.image')
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)

          assert_equal(0, json_data['@graph'].size)
          assert_equal(0, json_data['meta']['total'].to_i)
        end
      end
    end
  end
end
