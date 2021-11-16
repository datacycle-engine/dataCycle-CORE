# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImageProxyTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include ActiveJob::TestHelper

    before(:all) do
      DataCycleCore::ImageUploader.enable_processing = true
    end

    after(:all) do
      DataCycleCore::ImageUploader.enable_processing = false
    end

    def upload_image(file_name)
      file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
      image = DataCycleCore::Image.new(file: File.open(file_path))
      image.save
      image
    end

    test 'image proxy enabled' do
      is_enabled = DataCycleCore::Feature::ImageProxy.enabled?
      DataCycleCore.features[:image_proxy][:enabled] = true
      DataCycleCore::Feature::ImageProxy.instance_variable_set(:@enabled, true)
      assert DataCycleCore::Feature::ImageProxy.enabled?

      image = upload_image 'test_rgb.jpg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      validate_proxy_urls(DataCycleCore::Feature::ImageProxy.config, content)

      # unknown variant or variant with incorrect configuration must return nil
      assert_nil(DataCycleCore::Feature::ImageProxy.process_image(content: content, variant: 'dynamic'))
      assert_nil(DataCycleCore::Feature::ImageProxy.process_image(content: content, variant: 'unkown'))

      DataCycleCore.features[:image_proxy][:enabled] = is_enabled
      DataCycleCore::Feature::ImageProxy.instance_variable_set(:@enabled, is_enabled)
    end

    test 'image proxy disabled' do
      is_enabled = DataCycleCore::Feature::ImageProxy.enabled?
      DataCycleCore.features[:image_proxy][:enabled] = false
      DataCycleCore::Feature::ImageProxy.instance_variable_set(:@enabled, false)

      assert_not DataCycleCore::Feature::ImageProxy.enabled?

      image = upload_image 'test_rgb.jpg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      config = DataCycleCore::Feature::ImageProxy.config

      config.each do |variant, _processing|
        assert_nil DataCycleCore::Feature::ImageProxy.process_image(content: content, variant: variant)
      end

      DataCycleCore.features[:image_proxy][:enabled] = is_enabled
      DataCycleCore::Feature::ImageProxy.instance_variable_set(:@enabled, is_enabled)
    end

    test 'image proxy frontend enabled' do
      is_frontend_enabled = DataCycleCore::Feature::ImageProxy.frontend_enabled?
      DataCycleCore.features[:image_proxy][:frontend][:enabled] = true

      assert DataCycleCore::Feature::ImageProxy.frontend_enabled?

      image = upload_image 'test_rgb.jpg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      assert_equal(content.thumbnail_url, DataCycleCore::Feature::ImageProxy.process_image(content: content, variant: 'thumb'))
      assert_equal(content.asset_web_url, DataCycleCore::Feature::ImageProxy.process_image(content: content, variant: 'web'))

      DataCycleCore.features[:image_proxy][:frontend][:enabled] = is_frontend_enabled
    end

    test 'image proxy frontend disabled' do
      is_frontend_enabled = DataCycleCore::Feature::ImageProxy.frontend_enabled?
      DataCycleCore.features[:image_proxy][:frontend][:enabled] = false

      assert_not DataCycleCore::Feature::ImageProxy.frontend_enabled?

      image = upload_image 'test_rgb.jpg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      assert_equal(content.thumbnail_url, content.thumbnail_url)
      assert_equal(content.asset_web_url, content.asset.web.url)

      DataCycleCore.features[:image_proxy][:frontend][:enabled] = is_frontend_enabled
    end

    test 'image proxy can handle local and external things' do
      is_enabled = DataCycleCore::Feature::ImageProxy.enabled?
      DataCycleCore.features[:image_proxy][:enabled] = true
      DataCycleCore::Feature::ImageProxy.instance_variable_set(:@enabled, true)
      assert DataCycleCore::Feature::ImageProxy.enabled?

      # local content
      image = upload_image 'test_rgb.jpg'
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image.id })

      validate_proxy_urls(DataCycleCore::Feature::ImageProxy.config, content)

      external_content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', content_url: 'https://url.to.image/image.png' })
      external_content.update_columns(external_source_id: DataCycleCore::ExternalSystem.first.id, external_key: 'external_image_key')

      assert external_content.external?

      validate_proxy_urls(DataCycleCore::Feature::ImageProxy.config, content)

      DataCycleCore.features[:image_proxy][:enabled] = is_enabled
      DataCycleCore::Feature::ImageProxy.instance_variable_set(:@enabled, is_enabled)
    end

    def validate_proxy_urls(config, content)
      allowed_schemes = ['http', 'https']

      config.each do |variant, processing|
        next if variant == 'dynamic'
        proxy_url = DataCycleCore::Feature::ImageProxy.process_image(content: content, variant: variant)

        assert allowed_schemes.include?(Addressable::URI.parse(proxy_url).scheme)
        assert_equal(proxy_url, DataCycleCore::Feature::ImageProxy.process_image(content: content, variant: variant, image_processing: processing&.dig('processing')))
      end

      # testing dynamic url
      dynamic_url = DataCycleCore::Feature::ImageProxy.process_image(
        content: content,
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
  end
end
