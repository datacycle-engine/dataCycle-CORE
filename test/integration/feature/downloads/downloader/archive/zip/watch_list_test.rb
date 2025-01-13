# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Downloader
        module Archive
          module Zip
            class WatchListTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                @routes = Engine.routes
                @current_user = User.find_by(email: 'tester@datacycle.at')
                image = upload_image('test_rgb.jpeg')
                image_data_hash = {
                  'name' => 'image_headline',
                  'asset' => image.id
                }
                @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)
                @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
                @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
                DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
                DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @image.id)
                @serialize_config = DataCycleCore.features[:serialize].deep_dup
                @download_config = DataCycleCore.features[:download].deep_dup
              end

              setup do
                sign_in(@current_user)
              end

              test 'check if content collection serializer is disabled' do
                assert_not DataCycleCore.features.dig(:download, :downloader, :archive, :zip, :watch_list, :enabled)
                assert_not DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip])

                get download_zip_watch_list_path(@watch_list), params: { serialize_format: { 'asset' => 1, 'json' => 1, 'xml' => 1 } }, headers: {
                  referer: watch_list_path(@watch_list)
                }

                assert_equal(302, response.status)
              end

              test 'enable content collection and test zip download' do
                DataCycleCore.features[:serialize][:serializers][:asset] = true
                DataCycleCore.features[:serialize][:serializers][:json] = true
                DataCycleCore.features[:serialize][:serializers][:xml] = true
                DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = true
                DataCycleCore.features[:download][:downloader][:archive][:zip][:watch_list][:enabled] = true
                DataCycleCore.features[:download][:downloader][:archive][:zip][:watch_list][:serializers] = {
                  asset: true,
                  json: true,
                  xml: true
                }
                assert DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip])

                get download_zip_watch_list_path(@watch_list), params: { serialize_format: { 'asset' => 1, 'json' => 1, 'xml' => 1 } }, headers: {
                  referer: watch_list_path(@watch_list)
                }
                assert_response :success
                assert_equal('application/zip', response.headers['Content-Type'])
              end

              test 'enable content collection and test zip download via downloads controller' do
                DataCycleCore.features[:serialize][:serializers][:asset] = true
                DataCycleCore.features[:serialize][:serializers][:json] = true
                DataCycleCore.features[:serialize][:serializers][:xml] = true
                DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = true
                DataCycleCore.features[:download][:downloader][:archive][:zip][:watch_list][:enabled] = true
                DataCycleCore.features[:download][:downloader][:archive][:zip][:watch_list][:serializers] = {
                  asset: true,
                  json: true,
                  xml: true
                }
                assert DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip])

                get "/downloads/watch_list_collections/#{@watch_list.id}", params: { serialize_format: 'asset, json, xml' }
                assert_response :success
                assert_equal('application/zip', response.headers['Content-Type'])
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
