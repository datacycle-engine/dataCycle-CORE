# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class AssetTest < ActiveSupport::TestCase
      def setup
        DataCycleCore::ImageUploader.enable_processing = true
        @asset_temp = DataCycleCore::Image.count
      end

      def upload_asset(file_name)
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @asset = DataCycleCore::Image.new(file: File.open(file_path))
        @asset.save

        assert(@asset.persisted?)
        assert(@asset.valid?)

        @asset.reload
      end

      def validate_asset(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Image.count)
        # check asset data
        assert(@asset.file_size.positive?)
        assert_equal(file_name, @asset.name)
        assert_equal('DataCycleCore::Image', @asset.type)
      end

      def data_hash(asset)
        { 'name' => 'name', 'description' => 'description', 'asset' => asset }
      end

      test 'upload asset: Image: rgb/jpg' do
        file_name = 'test_rgb.jpg'
        upload_asset file_name

        assert_equal('image/jpeg', @asset.content_type)

        validate_asset file_name
      end

      test 'save without uploading a file' do
        @asset = DataCycleCore::Image.new
        @asset.save

        assert_not(@asset.persisted?)
        assert_not(@asset.valid?)
        assert_equal(@asset.errors.messages.size, 1)
      end

      test 'save asset in a data_hash' do
        asset_name = 'test_rgb.gif'
        asset = upload_asset(asset_name)
        data = DataCycleCore::TestPreparations.create_content(template_name: 'Asset-Template-1', data_hash: data_hash(asset))

        assert(data.asset.present?)
        assert_equal(asset.id, data.asset.id)
      end

      test 'save asset in data_hash, stays the same if set(get) is called' do
        asset_name = 'test_rgb.gif'
        asset = upload_asset(asset_name)
        data = DataCycleCore::TestPreparations.create_content(template_name: 'Asset-Template-1', data_hash: data_hash(asset))
        data.set_data_hash(data_hash: data.get_data_hash, force_update: true)

        assert(data.asset.present?)
        assert_equal(asset.id, data.asset.id)
      end

      test 'save asset in data_hash and replace it with another asset' do
        asset_name = 'test_rgb.gif'
        asset = upload_asset(asset_name)
        data = DataCycleCore::TestPreparations.create_content(template_name: 'Asset-Template-1', data_hash: data_hash(asset))

        asset_name2 = 'test_rgb.png'
        asset2 = upload_asset(asset_name2)
        data.set_data_hash(data_hash: data_hash(asset2))

        assert_equal(asset2.id, data.asset.id)
      end

      test 'save asset in data_hash and replace it with another asset with uuid' do
        asset_name = 'test_rgb.gif'
        asset = upload_asset(asset_name)
        data = DataCycleCore::TestPreparations.create_content(template_name: 'Asset-Template-1', data_hash: data_hash(asset.id))

        asset_name2 = 'test_rgb.png'
        asset2 = upload_asset(asset_name2)
        data.set_data_hash(data_hash: data_hash(asset2.id))

        assert_equal(asset2.id, data.asset.id)
      end

      test 'dont delete asset, when translation of content is destroyed' do
        asset = upload_asset('test_rgb.jpg')
        test_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: asset })
        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            test_image.set_data_hash(partial_update: true, data_hash: { name: "Test Bild 1 #{locale}" }.stringify_keys)
          end
        end

        assert_equal I18n.available_locales.size, test_image.translations.size

        I18n.with_locale(I18n.available_locales.first) do
          test_image.destroy_content({ destroy_locale: true })
        end

        assert_equal I18n.available_locales.size - 1, test_image.translations.size
        assert_equal asset.id, test_image.asset&.id
      end

      test 'delete asset, if last translation is destroyed' do
        asset = upload_asset('test_rgb.jpg')
        test_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: asset })
        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            test_image.set_data_hash(partial_update: true, data_hash: { name: "Test Bild 1 #{locale}" }.stringify_keys)
          end
        end

        assert_equal I18n.available_locales.size, test_image.translations.size

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            test_image.destroy_content({ destroy_locale: true })
          end
        end

        assert test_image.destroyed?
        assert_not Asset.exists?(id: asset.id)
      end

      test 'delete asset, if content is destroyed' do
        asset = upload_asset('test_rgb.jpg')
        test_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: asset })
        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            test_image.set_data_hash(partial_update: true, data_hash: { name: "Test Bild 1 #{locale}" }.stringify_keys)
          end
        end

        assert_equal I18n.available_locales.size, test_image.translations.size

        test_image.destroy_content

        assert test_image.destroyed?
        assert_not Asset.exists?(id: asset.id)
      end

      def teardown
        return if @asset.id.blank?
        @asset.remove_file!
        DataCycleCore::ImageUploader.enable_processing = false
      end
    end
  end
end
