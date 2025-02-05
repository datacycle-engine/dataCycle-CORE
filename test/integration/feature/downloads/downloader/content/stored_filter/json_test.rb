# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Downloader
        module Content
          module StoredFilter
            class JsonTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                @routes = Engine.routes
                @current_user = User.find_by(email: 'tester@datacycle.at')
                @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
                @stored_filter = DataCycleCore::StoredFilter.create(
                  name: 'TestFilter',
                  user_id: @current_user.id,
                  language: ['de'],
                  parameters: [],
                  api: true
                )
                @serialize_config = DataCycleCore.features[:serialize].deep_dup
                @download_config = DataCycleCore.features[:download].deep_dup
              end

              setup do
                sign_in(@current_user)
              end

              test 'check if json serializer is disabled for stored_filters' do
                assert_not DataCycleCore.features.dig(:serialize, :serializers, :json)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :stored_filter, :enabled)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :stored_filter, :serializers, :json)
                assert_not DataCycleCore::Feature::Download.allowed?(@stored_filter)

                get download_stored_filter_path(@stored_filter), params: { serialize_format: 'json' }, headers: {
                  referer: stored_filter_path(@stored_filter)
                }
                assert_equal(302, response.status)
              end

              test 'enable stored_filter json serializer and render json download for stored_filter' do
                DataCycleCore.features[:serialize][:serializers][:json] = true
                DataCycleCore.features[:download][:downloader][:content][:stored_filter][:enabled] = true
                DataCycleCore.features[:download][:downloader][:content][:stored_filter][:serializers][:json] = true
                assert DataCycleCore::Feature::Download.allowed?(@stored_filter)

                get download_stored_filter_path(@stored_filter), params: { serialize_format: 'json' }, headers: {
                  referer: stored_filter_path(@stored_filter)
                }

                assert_response :success
                assert_equal(@content.name, response.parsed_body['data'].first['headline'])
              end

              test 'enable stored_filter json serializer and test downloads controller' do
                DataCycleCore.features[:serialize][:serializers][:json] = true
                DataCycleCore.features[:download][:downloader][:content][:stored_filter][:enabled] = true
                DataCycleCore.features[:download][:downloader][:content][:stored_filter][:serializers][:json] = true
                assert DataCycleCore::Feature::Download.allowed?(@stored_filter)

                get "/downloads/stored_filters/#{@stored_filter.id}", params: { serialize_format: 'json' }, headers: {
                  referer: stored_filter_path(@stored_filter)
                }

                assert_response :success
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
