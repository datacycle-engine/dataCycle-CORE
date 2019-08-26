# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Content
        class AssetTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes
            sign_in(@current_user = User.find_by(email: 'tester@datacycle.at'))
            @image = DataCycleCore::Image.create!(file: File.open(File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb.jpg')), creator: @current_user)
            image_data_hash = {
              'name' => 'image_headline',
              'asset' => @image.id
            }
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash, user: @current_user)
          end

          test 'check if asset serializer is disabled' do
            asset_serializer_setting = DataCycleCore.features.dig(:serialize, :serializers, :asset)
            assert_not asset_serializer_setting

            get download_thing_path(@content), params: { serialize_format: 'asset' }, headers: {
              referer: thing_path(@content)
            }

            assert_equal(302, response.status)
          end

          test 'enable asset serializer and render json asset for image' do
            DataCycleCore.features[:serialize][:serializers][:asset] = true

            get download_thing_path(@content), params: { serialize_format: 'asset' }, headers: {
              referer: thing_path(@content)
            }
            assert_response :success
            assert_equal('image/jpeg', response.headers.dig('Content-Type'))
          end

          test 'enable asset serializer and test downloads controller' do
            DataCycleCore.features[:serialize][:serializers][:asset] = true

            get "/downloads/things/#{@content.id}", params: { serialize_format: 'asset' }, headers: {
              referer: thing_path(@content)
            }
            assert_response :success
            assert_equal('image/jpeg', response.headers.dig('Content-Type'))
          end

          def teardown
            DataCycleCore.features[:serialize][:serializers][:asset] = false
          end
        end
      end
    end
  end
end
