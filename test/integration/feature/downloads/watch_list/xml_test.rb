# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module WatchList
        class XmlTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
            @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'check if xml serializer is disabled for watch_lists' do
            assert_not DataCycleCore.features.dig(:download, :collections, :watch_list, :enabled)

            get download_watch_list_path(@watch_list), params: { serialize_format: 'xml' }, headers: {
              referer: watch_list_path(@watch_list)
            }

            assert_equal(302, response.status)
          end

          test 'enable watch_list xml serializer and render xml download for watch_list' do
            DataCycleCore.features[:serialize][:serializers][:xml] = true
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = true
            DataCycleCore.features[:download][:collections][:watch_list][:serializers][:xml] = true

            get download_watch_list_path(@watch_list), params: { serialize_format: 'xml' }, headers: {
              referer: watch_list_path(@watch_list)
            }

            assert_response :success
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal @watch_list.name, xml.xpath('//schema:collection/schema:name').text
            assert_equal @content.name, xml.xpath('//schema:collection/schema:things/schema:thing/schema:name').text
          end

          test 'enable watch_list xml serializer and test downloads controller' do
            DataCycleCore.features[:serialize][:serializers][:xml] = true
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = true
            DataCycleCore.features[:download][:collections][:watch_list][:serializers][:xml] = true

            get "/downloads/watch_lists/#{@watch_list.id}", params: { serialize_format: 'xml' }, headers: {
              referer: watch_list_path(@watch_list)
            }

            assert_response :success
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal @watch_list.name, xml.xpath('//schema:collection/schema:name').text
            assert_equal @content.name, xml.xpath('//schema:collection/schema:things/schema:thing/schema:name').text
          end

          def teardown
            DataCycleCore.features[:serialize][:serializers][:xml] = false
            DataCycleCore.features[:download][:collections][:watch_list][:enabled] = false
            DataCycleCore.features[:download][:collections][:watch_list][:serializers][:xml] = false
          end
        end
      end
    end
  end
end
