# frozen_string_literal: true

require 'test_helper'
require 'rack/test'

module DataCycleCore
  class GenericCommonFunctionsLocalAssetsTest < ActiveSupport::TestCase
    SUBJECT = DataCycleCore::Generic::Common::Functions
    IMAGE_FIXTURE = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb.jpeg')

    def with_local_import_file(source_file = IMAGE_FIXTURE, extension = '.jpeg')
      import_dir = Rails.root.join('private', 'import')
      FileUtils.mkdir_p(import_dir)
      tmp_file = Tempfile.new(['local_asset', extension], import_dir)
      FileUtils.cp(source_file, tmp_file.path)

      yield tmp_file.path
    ensure
      tmp_file&.close!
    end

    test 'local_asset returns data_hash unchanged when attribute is blank' do
      data_hash = { 'name' => 'no asset' }

      assert_equal data_hash, SUBJECT.local_asset(data_hash, 'image', 'image')
    end

    test 'local_asset creates asset from uploaded file hash' do
      uploaded_file = Rack::Test::UploadedFile.new(IMAGE_FIXTURE, 'image/jpeg')
      creator = DataCycleCore::User.first
      data_hash = { 'image' => { 'file' => uploaded_file } }

      assert_difference -> { DataCycleCore::Image.count } do
        SUBJECT.local_asset(data_hash, 'image', 'image', creator.id)
      end

      asset = DataCycleCore::Image.find(data_hash['image'])

      assert_equal 'test_rgb.jpeg', asset.name
      assert_equal creator.id, asset.creator_id
      assert_predicate asset.file, :attached?
    end

    test 'local_asset removes attribute on processing error' do
      data_hash = { 'image' => '/tmp/not_allowed_path.jpeg', 'name' => 'broken' }

      result = nil

      assert_no_difference -> { DataCycleCore::Image.count } do
        result = SUBJECT.local_asset(data_hash, 'image', 'image')
      end

      assert_not result.key?('image')
      assert_equal 'broken', result['name']
    end

    test 'local_asset raises on processing error when raise_exception is set' do
      data_hash = { 'image' => '/tmp/not_allowed_path.jpeg' }

      assert_raises(DataCycleCore::Error::Asset::RemoteFileDownloadError) do
        SUBJECT.local_asset(data_hash, 'image', 'image', nil, true)
      end
      assert_not data_hash.key?('image')
    end

    test 'local_image returns data_hash unchanged when attribute is blank' do
      data_hash = { 'name' => 'no image' }

      assert_equal data_hash, SUBJECT.local_image(data_hash, 'image_url')
    end

    test 'local_image creates image from allowed local path' do
      with_local_import_file do |file_path|
        data_hash = { 'image_url' => file_path }

        assert_difference -> { DataCycleCore::Image.count } do
          SUBJECT.local_image(data_hash, 'image_url')
        end

        asset = DataCycleCore::Image.find(data_hash['image_url'])

        assert_predicate asset.file, :attached?
        assert_equal 'image/jpeg', asset.content_type
      end
    end

    test 'local_image keeps attribute value on processing error' do
      data_hash = { 'image_url' => '/tmp/not_allowed_path.jpeg' }

      result = nil

      assert_no_difference -> { DataCycleCore::Image.count } do
        result = SUBJECT.local_image(data_hash, 'image_url')
      end

      assert_equal '/tmp/not_allowed_path.jpeg', result['image_url']
    end

    test 'local_video returns data_hash unchanged when attribute is blank' do
      data_hash = { 'name' => 'no video' }

      assert_equal data_hash, SUBJECT.local_video(data_hash, 'video_url')
    end

    test 'local_video creates video from allowed local path' do
      video_fixture = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'videos', 'test.mp4')

      with_local_import_file(video_fixture, '.mp4') do |file_path|
        data_hash = { 'video_url' => file_path }

        assert_difference -> { DataCycleCore::Video.count } do
          SUBJECT.local_video(data_hash, 'video_url')
        end

        asset = DataCycleCore::Video.find(data_hash['video_url'])

        assert_predicate asset.file, :attached?
        assert_equal 'video/mp4', asset.content_type
      end
    end

    test 'local_video keeps attribute value on processing error' do
      data_hash = { 'video_url' => '/tmp/not_allowed_path.mp4' }

      result = nil

      assert_no_difference -> { DataCycleCore::Video.count } do
        result = SUBJECT.local_video(data_hash, 'video_url')
      end

      assert_equal '/tmp/not_allowed_path.mp4', result['video_url']
    end
  end
end
