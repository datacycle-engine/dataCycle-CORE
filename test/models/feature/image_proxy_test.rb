# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImageProxyTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include ActiveJob::TestHelper

    before(:all) do
      @image_proxy_config = DataCycleCore.features[:image_proxy].deep_dup
    end

    test 'image proxy enabled' do
      DataCycleCore.features[:image_proxy][:enabled] = true
      DataCycleCore::Feature::ImageProxy.reload
      assert DataCycleCore::Feature::ImageProxy.enabled?

      image = upload_image 'test_rgb.jpeg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      validate_proxy_urls(DataCycleCore::Feature::ImageProxy.config, content)

      # unknown variant or variant with incorrect configuration must return nil
      assert_nil(DataCycleCore::Feature::ImageProxy.process_image(content:, variant: 'dynamic'))
      assert_nil(DataCycleCore::Feature::ImageProxy.process_image(content:, variant: 'unkown'))
    end

    test 'image proxy disabled' do
      DataCycleCore.features[:image_proxy][:enabled] = false
      DataCycleCore::Feature::ImageProxy.reload
      assert_not DataCycleCore::Feature::ImageProxy.enabled?

      image = upload_image 'test_rgb.jpeg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      config = DataCycleCore::Feature::ImageProxy.config

      config.each_key do |variant|
        assert_nil DataCycleCore::Feature::ImageProxy.process_image(content:, variant:)
      end
    end

    test 'image proxy frontend enabled' do
      DataCycleCore.features[:image_proxy][:frontend][:enabled] = true
      assert DataCycleCore::Feature::ImageProxy.frontend_enabled?

      image = upload_image 'test_rgb.jpeg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      assert_equal(content.thumbnail_url, DataCycleCore::Feature::ImageProxy.process_image(content:, variant: 'thumb'))
      assert_equal(content.asset_web_url, DataCycleCore::Feature::ImageProxy.process_image(content:, variant: 'web'))
    end

    test 'image proxy frontend disabled' do
      DataCycleCore.features[:image_proxy][:frontend][:enabled] = false
      assert_not DataCycleCore::Feature::ImageProxy.frontend_enabled?

      image = upload_image 'test_rgb.jpeg'
      assert image.thumb_preview.present?
      assert image.web.present?
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      assert_equal(content.thumbnail_url, active_storage_url_for(content.asset.thumb_preview))
      assert_equal(content.asset_web_url, active_storage_url_for(content.asset.web))
    end

    test 'image proxy can handle local and external things' do
      DataCycleCore.features[:image_proxy][:enabled] = true
      DataCycleCore::Feature::ImageProxy.reload
      assert DataCycleCore::Feature::ImageProxy.enabled?

      # local content
      image = upload_image 'test_rgb.jpeg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      validate_proxy_urls(DataCycleCore::Feature::ImageProxy.config, content)

      external_content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', content_url: 'https://url.to.image/image.png' })
      external_content.update_columns(external_source_id: DataCycleCore::ExternalSystem.first.id, external_key: 'external_image_key')

      assert external_content.external?

      validate_proxy_urls(DataCycleCore::Feature::ImageProxy.config, content)
    end

    def validate_proxy_urls(config, content)
      allowed_schemes = ['http', 'https']

      config.each do |variant, processing|
        next if variant == 'dynamic'
        proxy_url = DataCycleCore::Feature::ImageProxy.process_image(content:, variant:)

        assert allowed_schemes.include?(Addressable::URI.parse(proxy_url).scheme)
        assert_equal(proxy_url, DataCycleCore::Feature::ImageProxy.process_image(content:, variant:, image_processing: processing&.dig('processing')))
      end

      # testing dynamic url
      dynamic_url = DataCycleCore::Feature::ImageProxy.process_image(
        content:,
        variant: 'dynamic',
        image_processing: {
          'resize_type' => 'fit',
          'width' => 2048,
          'height' => 2048,
          'enlarge' => 0,
          'gravity' => 'ce',
          'format' => 'png'
        }
      )
      assert allowed_schemes.include?(Addressable::URI.parse(dynamic_url).scheme)
    end

    def teardown
      DataCycleCore.features[:image_proxy][:enabled] = @image_proxy_config[:enabled].dup
      DataCycleCore.features[:image_proxy][:frontend] = @image_proxy_config[:frontend].deep_dup
      DataCycleCore::Feature::ImageProxy.reload
    end
  end
end
