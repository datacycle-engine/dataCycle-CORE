# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Downloader
        module Content
          module Thing
            class AssetTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                @routes = Engine.routes
                @current_user = User.find_by(email: 'tester@datacycle.at')
                @image = upload_image('test_rgb.jpeg')
                image_data_hash = {
                  'name' => 'image_headline',
                  'asset' => @image.id
                }
                @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash, user: @current_user)
                @serialize_config = DataCycleCore.features[:serialize].deep_dup
                @download_config = DataCycleCore.features[:download].deep_dup
                @image_proxy_config = DataCycleCore.features[:image_proxy].deep_dup
              end

              setup do
                sign_in(@current_user)
              end

              test 'check if asset serializer is disabled' do
                assert_not DataCycleCore.features.dig(:serialize, :serializers, :asset)
                assert_not DataCycleCore.features.dig(:download, :downloader, :content, :thing, :serializers, :asset)
                assert_not DataCycleCore::Feature::Download.allowed?(@content)

                get download_thing_path(@content), params: { serialize_format: 'asset' }, headers: {
                  referer: thing_path(@content)
                }

                assert_equal(302, response.status)
              end

              test 'enable asset serializer and render asset for image' do
                DataCycleCore.features[:serialize][:serializers][:asset] = true
                DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:asset] = true
                DataCycleCore.features[:image_proxy][:enabled] = false
                DataCycleCore::Feature::ImageProxy.reload

                get download_thing_path(@content), params: { serialize_format: 'asset' }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/jpeg', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-original.jpeg"', content_disposition.second)

                # version thumb
                get download_thing_path(@content), params: { serialize_format: 'asset', version: 'thumb_preview' }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/jpeg', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-thumb_preview.jpeg"', content_disposition.second)

                # version web in png
                get download_thing_path(@content), params: { serialize_format: 'asset', version: 'web' }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/jpeg', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-web.jpeg"', content_disposition.second)

                # version web in png
                get download_thing_path(@content), params: { serialize_format: 'asset', version: 'web', transformation: { web: { format: 'png' } } }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/png', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-web.png"', content_disposition.second)

                #  transformation does not match version => transformation is ignored, version web is processed
                get download_thing_path(@content), params: { serialize_format: 'asset', version: 'web', transformation: { asdf: { format: 'png' } } }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/jpeg', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-web.jpeg"', content_disposition.second)

                #  invalid version => original file will be processed
                get download_thing_path(@content), params: { serialize_format: 'asset', version: 'test' }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/jpeg', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-original.jpeg"', content_disposition.second)
              end

              test 'enable asset serializer and test downloads controller' do
                DataCycleCore.features[:serialize][:serializers][:asset] = true
                DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:asset] = true
                DataCycleCore.features[:image_proxy][:enabled] = false
                DataCycleCore::Feature::ImageProxy.reload

                get "/downloads/things/#{@content.id}", params: { serialize_format: 'asset' }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/jpeg', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-original.jpeg"', content_disposition.second)

                # version thumb
                get download_thing_path(@content), params: { serialize_format: 'asset', version: 'thumb_preview' }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/jpeg', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-thumb_preview.jpeg"', content_disposition.second)

                # version web
                get "/downloads/things/#{@content.id}", params: { serialize_format: 'asset', version: 'web' }, headers: {
                  referer: thing_path(@content)
                }
                assert_response :success
                assert_equal('image/jpeg', response.headers.dig('Content-Type'))
                content_disposition = response.headers.dig('Content-Disposition').split(';')
                assert_equal('attachment', content_disposition.first)
                assert_equal(' filename="image_headline-web.jpeg"', content_disposition.second)
              end

              def teardown
                DataCycleCore.features[:serialize][:serializers] = @serialize_config[:serializers].deep_dup
                DataCycleCore.features[:download][:downloader] = @download_config[:downloader].deep_dup
                DataCycleCore.features[:image_proxy][:enabled] = @image_proxy_config[:enabled].deep_dup
                DataCycleCore::Feature::Serialize.reload
                DataCycleCore::Feature::Download.reload
                DataCycleCore::Feature::ImageProxy.reload
              end
              after(:all) do
                
              end
            end
          end
        end
      end
    end
  end
end
