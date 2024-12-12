# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Downloader
        module Content
          module WatchList
            class XmlTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
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

              test 'check if xml serializer is disabled for watch_lists' do
                assert_not DataCycleCore.features.dig(:serialize, :serializers, :xml)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :watch_list, :enabled)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :watch_list, :serializers, :xml)
                assert_not DataCycleCore::Feature::Download.allowed?(@watch_list)

                get download_watch_list_path(@watch_list), params: { serialize_format: 'xml' }, headers: {
                  referer: watch_list_path(@watch_list)
                }

                assert_equal(302, response.status)
              end

              test 'enable watch_list xml serializer and render xml download for watch_list' do
                DataCycleCore.features[:serialize][:serializers][:xml] = true
                DataCycleCore.features[:download][:downloader][:content][:watch_list][:enabled] = true
                DataCycleCore.features[:download][:downloader][:content][:watch_list][:serializers][:xml] = true
                assert DataCycleCore::Feature::Download.allowed?(@watch_list)

                get download_watch_list_path(@watch_list), params: { serialize_format: 'xml' }, headers: {
                  referer: watch_list_path(@watch_list)
                }

                assert_response :success
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal @watch_list.name, xml.xpath('//collection/name').text
                assert_equal @content.name, xml.xpath('//collection/things/thing/name').text
              end

              test 'enable watch_list xml serializer and test downloads controller' do
                DataCycleCore.features[:serialize][:serializers][:xml] = true
                DataCycleCore.features[:download][:downloader][:content][:watch_list][:enabled] = true
                DataCycleCore.features[:download][:downloader][:content][:watch_list][:serializers][:xml] = true
                assert DataCycleCore::Feature::Download.allowed?(@watch_list)

                get "/downloads/watch_lists/#{@watch_list.id}", params: { serialize_format: 'xml' }, headers: {
                  referer: watch_list_path(@watch_list)
                }

                assert_response :success
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal @watch_list.name, xml.xpath('//collection/name').text
                assert_equal @content.name, xml.xpath('//collection/things/thing/name').text
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
