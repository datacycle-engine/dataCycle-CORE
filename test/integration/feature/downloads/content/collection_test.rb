# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Content
        class CollectionTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes
            sign_in(@current_user = User.find_by(email: 'tester@datacycle.at'))
            image = DataCycleCore::Image.create!(file: File.open(File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb.jpg')), creator: @current_user)
            image_data_hash = {
              'name' => 'image_headline',
              'asset' => image.id
            }
            @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test', image: @image.id })
          end

          test 'check if content collection serializer is disabled' do
            asset_serializer_setting = DataCycleCore.features.dig(:download, :collections, :content, :enabled)
            assert_not asset_serializer_setting

            get download_zip_thing_path(@content), params: { serialize_format: { 'asset' => 1, 'json' => 1, 'xml' => 1 } }, headers: {
              referer: thing_path(@content)
            }

            assert_equal(302, response.status)
          end

          test 'enable content collection and test zip download' do
            DataCycleCore.features[:download][:collections][:content][:enabled] = true
            DataCycleCore.features[:serialize][:serializers][:asset] = true
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:serialize][:serializers][:xml] = true

            get download_zip_thing_path(@content), params: { serialize_format: { 'asset' => 1, 'json' => 1, 'xml' => 1 } }, headers: {
              referer: thing_path(@content)
            }
            assert_response :success
            assert_equal('application/zip', response.headers.dig('Content-Type'))
          end

          test 'enable content collection and test zip download via downloads controller' do
            DataCycleCore.features[:download][:collections][:content][:enabled] = true
            DataCycleCore.features[:serialize][:serializers][:asset] = true
            DataCycleCore.features[:serialize][:serializers][:json] = true
            DataCycleCore.features[:serialize][:serializers][:xml] = true

            get "/downloads/thing_collections/#{@content.id}", params: { serialize_format: 'asset, json, xml' }, headers: {
              referer: thing_path(@content)
            }
            assert_response :success
            assert_equal('application/zip', response.headers.dig('Content-Type'))
          end

          def teardown
            DataCycleCore.features[:download][:collections][:content][:enabled] = false
            DataCycleCore.features[:serialize][:serializers][:asset] = false
            DataCycleCore.features[:serialize][:serializers][:json] = false
            DataCycleCore.features[:serialize][:serializers][:xml] = false
          end
        end
      end
    end
  end
end
