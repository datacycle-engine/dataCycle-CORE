# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module StoredFilter
        class CollectionTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes

            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
            sign_in(User.find_by(email: 'tester@datacycle.at'))

            post(
              stored_filters_path,
              params: { stored_filter: { name: 'TestFilter' } },
              headers: { referer: root_path }
            )
            @stored_filter = User.find_by(email: 'tester@datacycle.at').stored_filters.presence&.find_by(name: 'TestFilter')
            @stored_filter.update(api: true)
          end

          test 'check if content collection serializer is disabled' do
            asset_serializer_setting = DataCycleCore.features.dig(:download, :collections, :stored_filter, :enabled)
            assert_not asset_serializer_setting

            get download_zip_stored_filter_path(@stored_filter), params: { serialize_format: { 'asset' => 1, 'json' => 1, 'xml' => 1 } }, headers: {
              referer: stored_filter_path(@stored_filter)
            }

            assert_equal(302, response.status)
          end

          test 'enable content collection and test zip download' do
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = true
            DataCycleCore.features[:serialize][:serializers][:asset] = true
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:serialize][:serializers][:xml] = true

            get download_zip_stored_filter_path(@stored_filter), params: { serialize_format: { 'asset' => 1, 'json' => 1, 'xml' => 1 } }, headers: {
              referer: stored_filter_path(@stored_filter)
            }

            assert_response :success
            assert_equal('application/zip', response.headers.dig('Content-Type'))
          end

          test 'enable content collection and test zip download via downloads controller' do
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = true
            DataCycleCore.features[:serialize][:serializers][:asset] = true
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:serialize][:serializers][:xml] = true

            get "/downloads/stored_filter_collections/#{@stored_filter.id}", params: { serialize_format: 'asset, json, xml' }
            assert_response :success
            assert_equal('application/zip', response.headers.dig('Content-Type'))
          end

          def teardown
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = false
            DataCycleCore.features[:serialize][:serializers][:asset] = false
            DataCycleCore.features[:serialize][:serializers][:json] = false
            DataCycleCore.features[:serialize][:serializers][:xml] = false
          end
        end
      end
    end
  end
end
