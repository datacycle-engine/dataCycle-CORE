# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class WatchListTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          before(:all) do
            @routes = Engine.routes
            @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'Merkliste 1')
            @current_user = User.find_by(email: 'tester@datacycle.at')
            @other_user = User.find_or_create_by(email: 'collection_impersonation@datacycle.at') do |u|
              u.given_name = 'Other'
              u.family_name = 'User'
              u.password = 'TGkfC7qekIjC'
              u.confirmed_at = 1.day.ago
              u.role = DataCycleCore::Role.find_by(name: 'standard')
            end
          end

          setup do
            sign_in(@current_user)
          end

          test '/api/v4/collections default results' do
            get api_v4_collections_path

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data['@graph'].length)
          end

          test '/api/v4/collections/:id default results' do
            get api_v4_collection_path(id: @watch_list.id)
            follow_redirect!

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal('Merkliste 1', json_data.dig('meta', 'collection', 'name'))
            assert_equal(0, json_data.dig('meta', 'total'))
            assert_equal(0, json_data.dig('meta', 'pages'))
            assert_equal(0, json_data['@graph'].length)
          end

          test '/api/v4/collections/ results with parameter user_email' do
            get api_v4_collections_path(user_email: 'tester@datacycle.at')

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal('Merkliste 1', json_data.dig('@graph', 0, 'name'))
            assert_equal(1, json_data.dig('meta', 'total'))
            assert_equal(1, json_data.dig('meta', 'pages'))
            assert_equal(1, json_data['@graph'].length)
          end

          test '/api/v4/endpoints/:id default results and /api/v4/users/' do
            post(
              stored_filters_path,
              params: { stored_filter: { name: 'TestFilter' }, update_filter_parameters: true },
              headers: { referer: root_path }
            )
            filter = User.find_by(email: 'tester@datacycle.at').stored_filters.presence&.find_by(name: 'TestFilter')

            assert_predicate(filter, :present?)
            assert_redirected_to(root_path(stored_filter: filter.id))
            follow_redirect!

            filter.update(api: true)
            get api_v4_stored_filter_path(id: filter.id)

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)

            get api_v4_users_path

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(['@context', '@graph'], json_data.keys)
            assert_equal(@watch_list.id, json_data.dig('@graph', 'watchLists', 0, 'id'))
            assert_equal(@watch_list.name, json_data.dig('@graph', 'watchLists', 0, 'name'))
            assert_equal(filter.id, json_data.dig('@graph', 'storedFilters', 0, 'id'))
            assert_equal(filter.name, json_data.dig('@graph', 'storedFilters', 0, 'name'))
            assert_equal('tester@datacycle.at', json_data.dig('@graph', 'userData', 'email'))
          end

          test '/api/v4/collections/:id/add_item add item to watch_list' do
            article = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })

            post add_item_api_v4_collection_path(id: @watch_list.id, thing_id: article.id)

            assert_response :success

            assert_equal @watch_list.things.pluck(:id), [article.id]
          end

          test '/api/v4/collections/:id/remove_item remove item to watch_list' do
            article = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
            @watch_list.things << article

            post remove_item_api_v4_collection_path(id: @watch_list.id, thing_id: article.id)

            assert_response :success

            assert_predicate @watch_list.things.pluck(:id), :blank?
          end

          test '/api/v4/collections/ with user_email of another user is unauthorized' do
            sign_in(@other_user)

            get api_v4_collections_path(user_email: @current_user.email)

            assert_response :unauthorized
          end

          test '/api/v4/collections/:id/add_item by a non-owner is unauthorized' do
            article = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'ForbiddenAdd' })
            sign_in(@other_user)

            post add_item_api_v4_collection_path(id: @watch_list.id, thing_id: article.id)

            assert_response :unauthorized
            assert_not_includes @watch_list.reload.things.pluck(:id), article.id
          end

          test '/api/v4/collections/:id/remove_item by a non-owner is unauthorized' do
            article = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'ForbiddenRemove' })
            @watch_list.things << article
            sign_in(@other_user)

            post remove_item_api_v4_collection_path(id: @watch_list.id, thing_id: article.id)

            assert_response :unauthorized
            assert_includes @watch_list.reload.things.pluck(:id), article.id

            @watch_list.things.destroy(article)
          end
        end
      end
    end
  end
end
