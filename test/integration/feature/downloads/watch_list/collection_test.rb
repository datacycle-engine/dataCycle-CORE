# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module WatchList
        class CollectionTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
            @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'check if content collection serializer is disabled' do
            asset_serializer_setting = DataCycleCore.features.dig(:download, :collections, :watch_list, :enabled)
            assert_not asset_serializer_setting

            get download_zip_watch_list_path(@watch_list), params: { serialize_format: { 'asset' => 1, 'json' => 1, 'xml' => 1 } }, headers: {
              referer: watch_list_path(@watch_list)
            }

            assert_equal(302, response.status)
          end

          test 'enable content collection and test zip download' do
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = true
            DataCycleCore.features[:serialize][:serializers][:asset] = true
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:serialize][:serializers][:xml] = true

            get download_zip_watch_list_path(@watch_list), params: { serialize_format: { 'asset' => 1, 'json' => 1, 'xml' => 1 } }, headers: {
              referer: watch_list_path(@watch_list)
            }
            assert_response :success
            assert_equal('application/zip', response.headers.dig('Content-Type'))
          end

          test 'enable content collection and test zip download via downloads controller' do
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = true
            DataCycleCore.features[:serialize][:serializers][:asset] = true
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:serialize][:serializers][:xml] = true

            get "/downloads/watch_list_collections/#{@watch_list.id}", params: { serialize_format: 'asset, json, xml' }
            assert_response :success
            assert_equal('application/zip', response.headers.dig('Content-Type'))
          end

          def teardown
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = false
            DataCycleCore.features[:serialize][:serializers][:asset] = false
            DataCycleCore.features[:serialize][:serializers][:json] = false
            DataCycleCore.features[:serialize][:serializers][:xml] = false
          end
        end
      end
    end
  end
end
