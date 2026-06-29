# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for the ImageEditor feature class methods: filename/mime extraction,
    # the web-safe mime check and the file_url web-safe / image-proxy / web-url
    # fallback branches. ImageProxy and configuration are stubbed so the URL logic
    # runs over lightweight content doubles without a real asset or feature config.
    class ImageEditorCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Feature::ImageEditor

      def content_double(name: 'photo.jpg', content_type: 'image/png', url: 'https://cdn.example/photo.png', web_url: 'https://cdn.example/web.jpg')
        struct_double(asset: struct_double(name:, content_type:, file: struct_double(url:)), web_url:)
      end

      test 'file_name strips the extension from the asset name' do
        assert_equal('photo', Subject.file_name(content_double(name: 'photo.jpg')))
        assert_equal('', Subject.file_name(nil))
      end

      test 'file_mime_type returns the asset content type' do
        assert_equal('image/png', Subject.file_mime_type(content_double))
      end

      test 'web_safe_mime_type? matches the web-safe mime list' do
        assert(Subject.web_safe_mime_type?('image/png'))
        assert_not(Subject.web_safe_mime_type?('image/tiff'))
      end

      test 'file_url returns the asset url for a web-safe type' do
        assert_equal('https://cdn.example/photo.png', Subject.file_url(content_double(content_type: 'image/png')))
      end

      test 'file_url uses the image proxy for a non web-safe type' do
        content = content_double(content_type: 'image/tiff')

        DataCycleCore::Feature::ImageProxy.stub(:enabled?, true) do
          DataCycleCore::Feature::ImageProxy.stub(:process_image, 'https://proxy.example/converted.png') do
            assert_equal('https://proxy.example/converted.png', Subject.file_url(content))
          end
        end
      end

      test 'file_url falls back to the web url when the proxy is disabled' do
        content = content_double(content_type: 'image/tiff')

        DataCycleCore::Feature::ImageProxy.stub(:enabled?, false) do
          assert_equal('https://cdn.example/web.jpg', Subject.file_url(content))
        end
      end

      test 'crop_options reads the configured custom crop options' do
        Subject.stub(:configuration, { custom_crop_options: [{ 'name' => 'square' }] }) do
          assert_equal([{ 'name' => 'square' }], Subject.crop_options)
        end
      end
    end
  end
end
