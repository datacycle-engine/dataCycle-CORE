# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module WatchList
        class JsonTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
            @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'check if json serializer is disabled for watch_lists' do
            assert_not DataCycleCore.features.dig(:serialize, :serializers, :json)
            assert_not DataCycleCore.features.dig(:download, :collections, :watch_list, :enabled)
            assert_not DataCycleCore.features.dig(:download, :collections, :watch_list, :serializers, :json)

            get download_watch_list_path(@watch_list), params: { serialize_format: 'json' }, headers: {
              referer: watch_list_path(@watch_list)
            }

            assert_equal(302, response.status)
          end

          test 'enable watch_list json serializer and render json download for watch_list' do
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = true
            DataCycleCore.features[:download][:collections][:watch_list][:serializers][:json] = true

            get download_watch_list_path(@watch_list), params: { serialize_format: 'json' }, headers: {
              referer: watch_list_path(@watch_list)
            }

            assert_response :success
            assert_equal(@watch_list.name, JSON.parse(response.body).dig('meta', 'watchList', 'name'))
            assert_equal(@content.name, JSON.parse(response.body).dig('data').first.dig('headline'))
          end

          test 'enable watch_list json serializer and test downloads controller' do
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = true
            DataCycleCore.features[:download][:collections][:watch_list][:serializers][:json] = true

            get "/downloads/watch_lists/#{@watch_list.id}", params: { serialize_format: 'json' }, headers: {
              referer: watch_list_path(@watch_list)
            }

            assert_response :success
            assert_equal(@watch_list.name, JSON.parse(response.body).dig('meta', 'watchList', 'name'))
            assert_equal(@content.name, JSON.parse(response.body).dig('data').first.dig('headline'))
          end

          def teardown
            DataCycleCore.features[:serialize][:serializers][:json] = false
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = false
            DataCycleCore.features[:download][:collections][:watch_list][:serializers][:json] = false
          end
        end
      end
    end
  end
end
