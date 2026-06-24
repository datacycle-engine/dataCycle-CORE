# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class AssetTest < ActiveSupport::TestCase
      include DataCycleCore::ActiveStorageHelper

      def setup
        @asset_temp = DataCycleCore::Image.count
      end

      def validate_asset(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Image.count)
        # check asset data
        assert_predicate(@asset.file_size, :positive?)
        assert_equal(file_name, @asset.name)
        assert_equal('DataCycleCore::Image', @asset.type)
      end

      def data_hash(asset)
        { 'name' => 'name', 'description' => 'description', 'asset' => asset }
      end

      test 'upload asset: Image: rgb/jpg' do
        file_name = 'test_rgb.jpeg'
        @asset = upload_image(file_name)

        assert_equal('image/jpeg', @asset.content_type)

        validate_asset file_name
      end

      test 'save without uploading a file' do
        @asset = DataCycleCore::Image.new
        @asset.save

        assert_not(@asset.persisted?)
        assert_not(@asset.valid?)
        assert_equal(1, @asset.errors.messages.size)
      end

      test 'save asset in a data_hash' do
        asset_name = 'test_rgb.gif'
        asset = upload_image(asset_name)
        data = DataCycleCore::TestPreparations.create_content(template_name: 'Asset-Template-1', data_hash: data_hash(asset))

        assert_predicate(data.asset, :present?)
        assert_equal(asset.id, data.asset.id)
      end

      test 'save asset in data_hash, stays the same if set(get) is called' do
        asset_name = 'test_rgb.gif'
        asset = upload_image(asset_name)
        data = DataCycleCore::TestPreparations.create_content(template_name: 'Asset-Template-1', data_hash: data_hash(asset))
        data.set_data_hash(data_hash: data.get_data_hash, force_update: true)

        assert_predicate(data.asset, :present?)
        assert_equal(asset.id, data.asset.id)
      end

      test 'save asset in data_hash and replace it with another asset' do
        asset_name = 'test_rgb.gif'
        asset = upload_image(asset_name)
        data = DataCycleCore::TestPreparations.create_content(template_name: 'Asset-Template-1', data_hash: data_hash(asset))

        asset_name2 = 'test_rgb.png'
        asset2 = upload_asset(asset_name2)
        data.set_data_hash(data_hash: data_hash(asset2))

        assert_equal(asset2.id, data.asset.id)
      end

      test 'save asset in data_hash and replace it with another asset with uuid' do
        asset_name = 'test_rgb.gif'
        asset = upload_image(asset_name)
        data = DataCycleCore::TestPreparations.create_content(template_name: 'Asset-Template-1', data_hash: data_hash(asset.id))

        asset_name2 = 'test_rgb.png'
        asset2 = upload_asset(asset_name2)
        data.set_data_hash(data_hash: data_hash(asset2.id))

        assert_equal(asset2.id, data.asset.id)
      end

      test 'dont delete asset, when translation of content is destroyed' do
        asset_name = 'test_rgb.gif'
        asset = upload_image(asset_name)

        assert_predicate asset.thumb_preview, :present?
        test_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: })
        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            test_image.set_data_hash(partial_update: true, data_hash: { name: "Test Bild 1 #{locale}" }.stringify_keys)
          end
        end

        assert_equal I18n.available_locales.size, test_image.translations.size

        I18n.with_locale(I18n.default_locale) do
          test_image.destroy_content(destroy_locale: true)
        end

        assert_equal I18n.available_locales.size - 1, test_image.translations.size
        assert_equal asset.id, test_image.asset&.id
      end

      test 'delete asset, if last translation is destroyed' do
        asset_name = 'test_rgb.jpeg'
        asset = upload_image(asset_name)
        test_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: })
        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            test_image.set_data_hash(partial_update: true, data_hash: { name: "Test Bild 1 #{locale}" }.stringify_keys)
          end
        end

        assert_equal I18n.available_locales.size, test_image.translations.size

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            test_image.destroy_content(destroy_locale: true)
          end
        end

        assert_predicate test_image, :destroyed?
        assert_not Asset.exists?(id: asset.id)
      end

      test 'delete asset, if content is destroyed' do
        asset_name = 'test_rgb.jpeg'
        asset = upload_image(asset_name)
        test_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: })
        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            test_image.set_data_hash(partial_update: true, data_hash: { name: "Test Bild 1 #{locale}" }.stringify_keys)
          end
        end

        assert_equal I18n.available_locales.size, test_image.translations.size

        test_image.destroy_content

        assert_predicate test_image, :destroyed?
        assert_not Asset.exists?(id: asset.id)
      end

      test 'remote_file_url allows allowed local import paths' do
        source_file = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb.jpeg')
        import_dirs = [
          Rails.root.join('private', 'import'),
          Rails.root.join('private', 'import', 'local_assets')
        ]

        temp_files = []

        import_dirs.each do |import_dir|
          FileUtils.mkdir_p(import_dir)
          tmp_file = Tempfile.new(['allowed', '.jpeg'], import_dir)
          FileUtils.cp(source_file, tmp_file.path)
          temp_files << tmp_file

          asset = DataCycleCore::Image.new(remote_file_url: tmp_file.path)
          asset.creator_id = @current_user.try(:id)

          assert asset.save
          assert_predicate asset.file, :attached?
        end
      ensure
        temp_files&.each(&:close!)
      end

      test 'remote_file_url rejects local paths outside allowed import dir' do
        source_file = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb.jpeg')
        disallowed_dirs = [
          Rails.root.join('private', 'not_allowed'),
          Rails.root.join('var', 'dcdata', 'import'),
          Rails.root.join('var', 'dcdata', 'not_allowed')
        ]

        temp_files = []

        disallowed_dirs.each do |disallowed_dir|
          FileUtils.mkdir_p(disallowed_dir)
          tmp_file = Tempfile.new(['blocked', '.jpeg'], disallowed_dir)
          FileUtils.cp(source_file, tmp_file.path)
          temp_files << tmp_file

          asset = DataCycleCore::Image.new(remote_file_url: tmp_file.path)
          asset.creator_id = @current_user.try(:id)

          assert_raises(DataCycleCore::Error::Asset::RemoteFileDownloadError) { asset.save }
        end
      ensure
        temp_files&.each(&:close!)
      end

      test 'remote_file_url rejects loopback, private and link-local addresses (SSRF)' do
        [
          'http://127.0.0.1/test.jpeg',
          'http://169.254.169.254/latest/meta-data/',
          'http://10.0.0.1/test.jpeg',
          'http://192.168.0.1/test.jpeg',
          'http://[::1]/test.jpeg'
        ].each do |url|
          asset = DataCycleCore::Image.new(remote_file_url: url)
          asset.creator_id = @current_user.try(:id)

          assert_raises(DataCycleCore::Error::Asset::RemoteFileDownloadError) { asset.save }
        end
      end

      test 'remote_file_url rejects disallowed url schemes (SSRF)' do
        [
          'ftp://example.com/test.jpeg',
          'gopher://example.com/'
        ].each do |url|
          asset = DataCycleCore::Image.new(remote_file_url: url)
          asset.creator_id = @current_user.try(:id)

          assert_raises(DataCycleCore::Error::Asset::RemoteFileDownloadError) { asset.save }
        end
      end
    end
  end
end
