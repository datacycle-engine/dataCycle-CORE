# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class AssetTest < ActiveSupport::TestCase
      def setup
        @asset_temp = DataCycleCore::Asset.count
      end

      def upload_asset(file_name)
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @asset = DataCycleCore::Asset.new(file: File.open(file_path))
        @asset.save

        assert(@asset.persisted?)
        assert(@asset.valid?)

        @asset.reload
      end

      def validate_asset(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Asset.count)
        # check asset data
        assert(@asset.file_size.positive?)
        assert_equal(file_name, @asset.name)
        assert_equal('DataCycleCore::Asset', @asset.type)
      end

      test 'upload asset: Image: rgb/jpg' do
        file_name = 'test_rgb.jpg'
        upload_asset file_name

        assert_equal('image/jpeg', @asset.content_type)

        validate_asset file_name
      end

      test 'save without uploading a file' do
        @asset = DataCycleCore::Asset.new
        @asset.save

        assert_not(@asset.persisted?)
        assert_not(@asset.valid?)
        assert_equal(@asset.errors.size, 1)
      end
    end
  end
end
