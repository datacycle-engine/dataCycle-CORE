# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Downloader
        module Content
          module WatchList
            class JsonTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                @routes = Engine.routes
                @current_user = User.find_by(email: 'tester@datacycle.at')
                @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
                @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
                DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
                @serialize_config = DataCycleCore.features[:serialize].deep_dup
                @download_config = DataCycleCore.features[:download].deep_dup
              end

              setup do
                sign_in(@current_user)
              end

              test 'check if json serializer is disabled for watch_lists' do
                assert_not DataCycleCore.features.dig(:serialize, :serializers, :json)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :watch_list, :enabled)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :watch_list, :serializers, :json)
                assert_not DataCycleCore::Feature::Download.allowed?(@watch_list)

                get download_watch_list_path(@watch_list), params: { serialize_format: 'json' }, headers: {
                  referer: watch_list_path(@watch_list)
                }

                assert_equal(302, response.status)
              end

              test 'enable watch_list json serializer and render json download for watch_list' do
                DataCycleCore.features[:serialize][:serializers][:json] = true
                DataCycleCore.features[:download][:downloader][:content][:watch_list][:enabled] = true
                DataCycleCore.features[:download][:downloader][:content][:watch_list][:serializers][:json] = true
                assert DataCycleCore::Feature::Download.allowed?(@watch_list)

                get download_watch_list_path(@watch_list), params: { serialize_format: 'json' }, headers: {
                  referer: watch_list_path(@watch_list)
                }

                assert_response :success
                assert_equal(@watch_list.name, response.parsed_body.dig('meta', 'watchList', 'name'))
                assert_equal(@content.name, response.parsed_body['data'].first['headline'])
              end

              test 'enable watch_list json serializer and test downloads controller' do
                DataCycleCore.features[:serialize][:serializers][:json] = true
                DataCycleCore.features[:download][:downloader][:content][:watch_list][:enabled] = true
                DataCycleCore.features[:download][:downloader][:content][:watch_list][:serializers][:json] = true
                assert DataCycleCore::Feature::Download.allowed?(@watch_list)

                get "/downloads/watch_lists/#{@watch_list.id}", params: { serialize_format: 'json' }, headers: {
                  referer: watch_list_path(@watch_list)
                }

                assert_response :success
                assert_equal(@watch_list.name, response.parsed_body.dig('meta', 'watchList', 'name'))
                assert_equal(@content.name, response.parsed_body['data'].first['headline'])
              end

              def teardown
                DataCycleCore.features[:serialize][:serializers] = @serialize_config[:serializers].deep_dup
                DataCycleCore.features[:download][:downloader] = @download_config[:downloader].deep_dup
                DataCycleCore::Feature::Serialize.reload
                DataCycleCore::Feature::Download.reload
              end
            end
          end
        end
      end
    end
  end
end
