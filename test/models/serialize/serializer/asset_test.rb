# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Serialize
    module Serializer
      # Coverage for the Asset serializer: the legacy file_extension helper and the
      # private #serialize image-proxy / remote branches. ImageProxy is stubbed so
      # the proxy URL building runs over lightweight content doubles without a real
      # asset, feature config or database.
      class AssetTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def serializer
          DataCycleCore::Serialize::Serializer::Asset
        end

        def image_proxy
          DataCycleCore::Feature::ImageProxy
        end

        test 'file_extension maps a mime type to a dotted extension' do
          assert_equal('.png', serializer.file_extension('image/png'))
        end

        test 'file_extension returns nil for an unknown mime type' do
          assert_nil(serializer.file_extension('application/x-does-not-exist'))
        end

        test 'serialize uses the image proxy with an explicit format' do
          content = struct_double(id: 'a1', title: 'Proxy Image', asset: nil, content_url: nil)

          image_proxy.stub(:enabled?, true) do
            image_proxy.stub(:supported_content_type?, true) do
              image_proxy.stub(:config, { 'thumb' => { 'processing' => { 'quality' => 80 } } }) do
                image_proxy.stub(:process_image, 'https://proxy.example/img.webp') do
                  result = serializer.send(:serialize, content, 'de', 'thumb_preview', { 'format' => 'webp' })

                  assert_kind_of(DataCycleCore::Serialize::SerializedData::Content, result)
                  assert_predicate(result, :is_remote)
                  assert_equal('https://proxy.example/img.webp', result.data_url)
                  assert_nil(result.data)
                end
              end
            end
          end
        end

        test 'serialize uses the image proxy variant without a transformation format' do
          content = struct_double(id: 'a2', title: 'Variant Image', asset: nil, content_url: nil)

          image_proxy.stub(:enabled?, true) do
            image_proxy.stub(:supported_content_type?, true) do
              image_proxy.stub(:process_image, 'https://proxy.example/thumb.jpg') do
                result = serializer.send(:serialize, content, 'de', 'thumb', nil)

                assert_predicate(result, :is_remote)
                assert_equal('https://proxy.example/thumb.jpg', result.data_url)
              end
            end
          end
        end

        test 'serialize falls back to the remote content url' do
          asset = struct_double(file: nil, versions: {})
          content = struct_double(id: 'r1', title: 'Remote Image', asset:, content_url: 'https://remote.example/photo.jpg')

          image_proxy.stub(:enabled?, false) do
            result = serializer.send(:serialize, content, 'de', 'original', nil)

            assert_predicate(result, :is_remote)
            assert_equal('https://remote.example/photo.jpg', result.data_url)
          end
        end
      end
    end
  end
end
