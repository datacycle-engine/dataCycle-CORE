# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module StoredFilter
        class JsonTest < ActionDispatch::IntegrationTest
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

          test 'check if json serializer is disabled for stored_filters' do
            assert_not DataCycleCore.features.dig(:serialize, :serializers, :json)
            assert_not DataCycleCore.features.dig(:download, :collections, :stored_filter, :enabled)
            assert_not DataCycleCore.features.dig(:download, :collections, :stored_filter, :serializers, :json)

            get download_stored_filter_path(@stored_filter), params: { serialize_format: 'json' }, headers: {
              referer: stored_filter_path(@stored_filter)
            }
            assert_equal(302, response.status)
          end

          test 'enable stored_filter json serializer and render json download for stored_filter' do
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = true
            DataCycleCore.features[:download][:collections][:stored_filter][:serializers][:json] = true

            get download_stored_filter_path(@stored_filter), params: { serialize_format: 'json' }, headers: {
              referer: stored_filter_path(@stored_filter)
            }

            assert_response :success
            assert_equal(@content.name, JSON.parse(response.body).dig('data').first.dig('headline'))
          end

          test 'enable stored_filter json serializer and test downloads controller' do
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = true
            DataCycleCore.features[:download][:collections][:stored_filter][:serializers][:json] = true

            get "/downloads/stored_filters/#{@stored_filter.id}", params: { serialize_format: 'json' }, headers: {
              referer: stored_filter_path(@stored_filter)
            }

            assert_response :success
            assert_equal(@content.name, JSON.parse(response.body).dig('data').first.dig('headline'))
          end

          def teardown
            DataCycleCore.features[:serialize][:serializers][:json] = false
            DataCycleCore.features[:download][:collections][:stored_filter][:enabled] = false
            DataCycleCore.features[:download][:collections][:stored_filter][:serializers][:json] = false
          end
        end
      end
    end
  end
end
