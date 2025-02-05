# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Downloader
        module Content
          module Thing
            class JsonTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                @routes = Engine.routes
                @current_user = User.find_by(email: 'tester@datacycle.at')
                @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
                @serialize_config = DataCycleCore.features[:serialize].deep_dup
                @download_config = DataCycleCore.features[:download].deep_dup
              end

              setup do
                sign_in(@current_user)
              end

              test 'check if json serializer is disabled' do
                assert_not DataCycleCore.features.dig(:serialize, :serializers, :json)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :thing, :serializers, :json)
                assert_not DataCycleCore::Feature::Download.allowed?(@content)

                get download_thing_path(@content), params: { serialize_format: 'json' }, headers: {
                  referer: thing_path(@content)
                }

                assert_equal(302, response.status)
              end

              test 'enable json serializer and render json download for article' do
                DataCycleCore.features[:serialize][:serializers][:json] = true
                DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:json] = true
                assert DataCycleCore::Feature::Download.allowed?(@content)

                get download_thing_path(@content), params: { serialize_format: 'json' }, headers: {
                  referer: thing_path(@content)
                }

                assert_response :success
                assert_equal(@content.name, response.parsed_body['headline'])
              end

              test 'enable json serializer and test downloads controller' do
                DataCycleCore.features[:serialize][:serializers][:json] = true
                DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:json] = true
                assert DataCycleCore::Feature::Download.allowed?(@content)

                get "/downloads/things/#{@content.id}", params: { serialize_format: 'json' }, headers: {
                  referer: thing_path(@content)
                }

                assert_response :success
                assert_equal(@content.name, response.parsed_body['headline'])
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
