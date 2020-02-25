# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class RoutingTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @test_content = DataCycleCore::DummyDataHelper.create_data('tour')
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        def add_stored_filter
          DataCycleCore::StoredFilter.create(
            name: 'fulltext',
            user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
            language: ['de'],
            parameters: [{
              'n' => 'Suchbegriff',
              't' => 'fulltext_search',
              'v' => 'test'
            }, {
              't' => 'order',
              'v' => "things.boost * (8 * similarity(searches.classification_string, '%Test-POI%') + 4 * similarity(searches.headline, '%Test-POI%') + 2 * ts_rank_cd(searches.words, plainto_tsquery('simple', 'Test-POI'),16) + 1 * similarity(searches.full_text, '%Test-POI%')) DESC NULLS LAST, things.updated_at DESC"
            }],
            api: true
          )
        end

        test '/api/v4/things' do
          count = DataCycleCore::Thing.where(template: false).with_content_type('entity').count

          get api_v4_things_path
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(count, json_data['@graph'].length)
          assert_equal(count, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test '/api/v4/things/:id' do
          get api_v4_thing_path(id: @test_content.id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(@test_content.id, json_data.dig('@id'))
        end

        test '/api/v4/things/deleted' do
          @test_content.destroy_content
          get api_v4_contents_deleted_path(filter: { deletedSince: '01-01-2010' })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test '/api/v4/endpoints/:uuid with a valid stored_filter' do
          fulltext_filter = add_stored_filter
          get api_v4_stored_filter_path(id: fulltext_filter.id, include: 'image,poi.image')

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(2, json_data['@graph'].size)
          assert_equal(2, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          poi = json_data.dig('@graph').detect { |i| i.dig('name') == 'Test-POI' }
          assert_equal(1, poi.dig('image')&.size)

          tour = json_data.dig('@graph').detect { |i| i.dig('name') == 'Test-TOUR' }
          assert_equal(1, tour.dig('image')&.size)
          assert_equal(1, tour.dig('poi', 0, 'image')&.size)
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
          fulltext_filter = add_stored_filter
          fulltext_filter.linked_stored_filter_id = height_filter.id
          fulltext_filter.save

          get api_v4_stored_filter_path(id: fulltext_filter.id, include: 'image,poi.image')

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(2, json_data['@graph'].size)
          assert_equal(2, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          poi = json_data.dig('@graph').detect { |i| i.dig('name') == 'Test-POI' }
          assert_nil(poi.dig('image'))

          tour = json_data.dig('@graph').detect { |i| i.dig('name') == 'Test-TOUR' }
          assert_nil(tour.dig('image'))
          assert_nil(tour.dig('poi', 0, 'image'))
        end

        test '/api/v4/endpoints/:uuid/ with random :uuid responds with 404' do
          get api_v4_stored_filter_path(id: SecureRandom.uuid)

          assert_response :not_found
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(['error'], json_data.keys)
        end

        test '/api/v4/collections/:uuid with random :uuid responds with 404' do
          get api_v4_collection_path(id: SecureRandom.uuid)

          assert_response :not_found
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(['error'], json_data.keys)
        end

        test '/api/v4/concept_schemes' do
          get api_v4_concept_schemes_path
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(['@context', '@graph', 'meta', 'links'].sort, json_data.keys.sort)
        end

        test '/api/v4/concept_schemes/id' do
          tree_id = DataCycleCore::ClassificationTreeLabel.where(name: 'Geschlecht').visible('api').first.id
          get api_v4_concept_scheme_path(id: tree_id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(tree_id, json_data.dig('@graph', 0, '@id'))
        end

        test '/api/v4/concept_schemes/id/concepts' do
          tree_id = DataCycleCore::ClassificationTreeLabel.where(name: 'Geschlecht').visible('api').first
          get classifications_api_v4_concept_scheme_path(id: tree_id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(['@context', '@graph', 'meta', 'links'].sort, json_data.keys.sort)
        end

        test '/api/v4/concept_schemes/id/concepts/classification_id' do
          tree = DataCycleCore::ClassificationTreeLabel.all.detect { |item| DataCycleCore::ClassificationAlias.for_tree(item.name).count.positive? }
          classification = DataCycleCore::ClassificationAlias.for_tree(tree.name).first

          get classifications_api_v4_concept_scheme_path(id: tree.id, classification_id: classification.id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(classification.id, json_data.dig('@id'))
        end

        test '/api/v4/users/:id' do
          user_id = User.find_by(email: 'tester@datacycle.at').id
          get api_v4_user_path(id: user_id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(user_id, json_data.dig('id'))
        end
      end
    end
  end
end
