# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class StoredFilterCollectionTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @user = User.find_by(email: 'guest@datacycle.at')
          DataCycleCore::Thing.delete_all
          @routes = Engine.routes
          @test_tour1 = create_content('Tour', { name: 'Testtour1' })
          @test_tour2 = create_content('Tour', { name: 'Testtour2' })
          @dynamic_collection = DataCycleCore::StoredFilter.create(
            name: 'Test Dynamic Collection',
            parameters: [{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Tour'] } }],
            user_id: @user.id,
            api: true
          )
          @static_collection = DataCycleCore::WatchList.create(
            full_path: 'Test Static Collection',
            things: [@test_tour1, @test_tour2],
            user_id: @user.id,
            api: true
          )
        end

        test 'POST /api/v4/endpoints with dynamic collection to create a static collection' do
          post api_v4_endpoints_path, params: {
            token: @user.access_token,
            endpoint: @dynamic_collection.id,
            collection: {
              '@type': WatchList::API_V4_TYPE,
              name: 'New Static Collection'
            }
          }

          assert_response :created
          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert_equal(1, json_data['@graph'].size)
          assert_equal('New Static Collection', json_data.dig('@graph', 0, 'name'))
          assert_predicate(json_data.dig('@graph', 0, '@id'), :present?)

          collection = DataCycleCore::WatchList.find(json_data.dig('@graph', 0, '@id'))

          assert(collection.api)
          sf = collection.to_stored_filter

          assert_equal([@test_tour2.id, @test_tour1.id], sf.things.pluck(:id))

          get api_v4_stored_filter_path(id: collection.slug), headers: { Authorization: "Bearer #{@user.access_token}" }

          assert_response :success
          assert_equal('application/json; charset=utf-8', response.content_type)
        end

        test 'POST /api/v4/endpoints with static collection to create a static collection with filter' do
          post api_v4_endpoints_path, params: {
            token: @user.access_token,
            endpoint: @static_collection.id,
            collection: {
              '@type': WatchList::API_V4_TYPE,
              name: 'New Static Collection'
            },
            filter: {
              contentId: {
                in: [@test_tour1.id]
              }
            }
          }

          assert_response :created
          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert_equal(1, json_data['@graph'].size)
          assert_equal('New Static Collection', json_data.dig('@graph', 0, 'name'))
          assert_predicate(json_data.dig('@graph', 0, '@id'), :present?)

          collection = DataCycleCore::WatchList.find(json_data.dig('@graph', 0, '@id'))

          assert(collection.api)
          sf = collection.to_stored_filter

          assert_equal([@test_tour1.id], sf.things.pluck(:id))

          get api_v4_stored_filter_path(id: collection.slug), headers: { Authorization: "Bearer #{@user.access_token}" }

          assert_response :success
          assert_equal('application/json; charset=utf-8', response.content_type)
        end

        test 'POST /api/v4/endpoints with static collection to create a static collection sorted by name' do
          post api_v4_endpoints_path, params: {
            token: @user.access_token,
            endpoint: @static_collection.id,
            collection: {
              '@type': WatchList::API_V4_TYPE,
              name: 'New Static Collection'
            },
            sort: 'name'
          }

          assert_response :created
          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert_equal(1, json_data['@graph'].size)
          assert_equal('New Static Collection', json_data.dig('@graph', 0, 'name'))
          assert_predicate(json_data.dig('@graph', 0, '@id'), :present?)

          collection = DataCycleCore::WatchList.find(json_data.dig('@graph', 0, '@id'))

          assert(collection.api)
          sf = collection.to_stored_filter

          assert_equal([@test_tour1.id, @test_tour2.id], sf.things.pluck(:id))

          get api_v4_stored_filter_path(id: collection.slug), headers: { Authorization: "Bearer #{@user.access_token}" }

          assert_response :success
          assert_equal('application/json; charset=utf-8', response.content_type)
        end

        test 'POST /api/v4/endpoints with static collection to create a static collection with validUntil' do
          post api_v4_endpoints_path, params: {
            token: @user.access_token,
            endpoint: @static_collection.id,
            collection: {
              '@type': WatchList::API_V4_TYPE,
              name: 'New Static Collection'
              # validUntil: 1.day.from_now.iso8601
            }
          }

          assert_response :created
          json_data = response.parsed_body
          collection = DataCycleCore::WatchList.find(json_data.dig('@graph', 0, '@id'))
          get api_v4_stored_filter_path(id: collection.slug), headers: { Authorization: "Bearer #{@user.access_token}" }

          assert_response :success

          travel 2.days do
            get api_v4_stored_filter_path(id: collection.slug), headers: { Authorization: "Bearer #{@user.access_token}" }
            # should fail if permissions in core are adjusted
            # assert_response :unauthorized
            assert_response :success
          end
        end

        test 'POST /api/v4/endpoints with non-existant collection' do
          post api_v4_endpoints_path, params: {
            token: @user.access_token,
            endpoint: SecureRandom.uuid,
            collection: {
              '@type': WatchList::API_V4_TYPE,
              name: 'New Static Collection'
            }
          }

          assert_response :not_found
        end

        test 'POST /api/v4/endpoints with random sorting' do
          post api_v4_endpoints_path, params: {
            token: @user.access_token,
            endpoint: @static_collection.id,
            collection: {
              '@type': WatchList::API_V4_TYPE,
              name: 'New Static Collection'
            },
            sort: 'random(0.45665)'
          }

          assert_response :success
        end
      end
    end
  end
end
