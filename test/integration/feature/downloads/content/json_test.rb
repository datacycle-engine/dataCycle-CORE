# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Content
        class JsonTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'check if json serializer is disabled' do
            json_serializer_setting = DataCycleCore.features.dig(:serialize, :serializers, :json)
            assert_not json_serializer_setting

            get download_thing_path(@content), params: { serialize_format: 'json' }, headers: {
              referer: thing_path(@content)
            }

            assert_equal(302, response.status)
          end

          test 'enable json serializer and render json download for article' do
            DataCycleCore.features[:serialize][:serializers][:json] = true

            get download_thing_path(@content), params: { serialize_format: 'json' }, headers: {
              referer: thing_path(@content)
            }

            assert_response :success
            assert response.body.include?(@content.name)
            assert_equal(@content.name, JSON.parse(response.body).dig('headline'))
          end

          test 'enable json serializer and test downloads controller' do
            DataCycleCore.features[:serialize][:serializers][:json] = true

            get "/downloads/things/#{@content.id}", params: { serialize_format: 'json' }, headers: {
              referer: thing_path(@content)
            }

            assert_response :success
            assert response.body.include?(@content.name)
            assert_equal(@content.name, JSON.parse(response.body).dig('headline'))
          end

          def teardown
            DataCycleCore.features[:serialize][:serializers][:json] = false
          end
        end
      end
    end
  end
end
