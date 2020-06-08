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
          assert_equal(tree_id, json_data.dig('@id'))
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
