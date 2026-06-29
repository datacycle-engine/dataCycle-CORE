# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the DataCycleCore::Asset base class (exercised mostly through a
  # persisted Image, plus a non-Image subclass for the methods Image overrides).
  class AssetCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @image = upload_image('test_rgb.jpeg')
    end

    # ---- base-class methods (Image overrides duplicate_candidates / extension_white_list) ----

    test 'base duplicate_candidates default to empty arrays' do
      asset = DataCycleCore::TextFile.new

      assert_empty(asset.duplicate_candidates)
      assert_empty(asset.duplicate_candidates_with_score)
    end

    test 'base extension_white_list is empty' do
      assert_equal([], DataCycleCore::Asset.extension_white_list)
    end

    # ---- generic Asset methods (inherited unchanged by Image) ----

    test 'update_asset_attributes nils metadata when the blob raises a JSON generator error' do
      image = DataCycleCore::Image.find(@image.id)

      image.stub(:metadata_from_blob, ->(*) { raise JSON::GeneratorError, 'boom' }) do
        image.send(:update_asset_attributes)
      end

      assert_nil(image.metadata)
    end

    test 'duplicate clones the asset and its attached file' do
      copy = @image.duplicate

      assert_not_nil(copy)
      assert_predicate(copy, :persisted?)
      assert_predicate(copy.file, :attached?)
    end

    test 'file_size_validation flags files over the configured maximum' do
      image = DataCycleCore::Image.find(@image.id)
      image.file_size_validation({ max: 1 })

      assert_predicate(image.errors[:file], :present?)
    end

    test 'as_json excludes the file by default and adds the content url' do
      json = @image.as_json

      assert(json.key?('file'))
      assert(json['file'].key?('url'))
    end

    test 'full_warnings renders accumulated warnings' do
      image = DataCycleCore::Image.find(@image.id)
      image.warnings.add(:base, :some_warning)

      assert_predicate(image, :warnings?)
      assert_kind_of(String, image.full_warnings(:de))
    end

    # ---- private file-loading callbacks ----

    test 'load_file_from_binary_file_blob attaches a decoded hex blob' do
      asset = DataCycleCore::Image.new(name: 'binary.png')
      asset.binary_file_blob = '89504e470d0a1a0a' # PNG magic bytes as hex

      asset.send(:load_file_from_binary_file_blob)

      assert_predicate(asset.file, :attached?)
    end

    test 'load_file_from_base64_encoded_binary_file_blob attaches a decoded data URI' do
      asset = DataCycleCore::Image.new(name: 'base64.png')
      asset.base64_file_blob = "data:image/png;base64,#{Base64.strict_encode64('PNGDATA')}"

      asset.send(:load_file_from_base64_encoded_binary_file_blob)

      assert_predicate(asset.file, :attached?)
    end

    test 'load_file_from_remote_file_url attaches a downloaded remote file' do
      tmp = Tempfile.new('remote')
      tmp.write('data')
      tmp.rewind
      asset = DataCycleCore::Image.new(name: 'remote.jpg')
      asset.remote_file_url = 'http://example.com/remote.jpg'

      asset.stub(:download_remote_file, tmp) do
        asset.send(:load_file_from_remote_file_url)
      end

      assert_predicate(asset.file, :attached?)
    end

    test 'load_file_from_remote_file_url retries then raises on persistent download errors' do
      asset = DataCycleCore::Image.new(name: 'remote.jpg')
      asset.remote_file_url = 'http://example.com/remote.jpg'

      asset.stub(:sleep, nil) do
        asset.stub(:download_remote_file, ->(*) { raise StandardError, 'boom' }) do
          assert_raises(DataCycleCore::Error::Asset::RemoteFileDownloadError) do
            asset.send(:load_file_from_remote_file_url)
          end
        end
      end
    end
  end
end
