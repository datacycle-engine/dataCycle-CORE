# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class VideoTest < ActiveSupport::TestCase
      include DataCycleCore::ActiveStorageHelper
      def setup
        # DataCycleCore::VideoUploader.enable_processing = true
        @video_temp = DataCycleCore::Video.count
      end

      def validate_video(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Video.count)
        # check video data
        assert(@video.file_size.positive?)
        assert_equal(file_name, @video.name)
        assert_equal('DataCycleCore::Video', @video.type)
        assert(@video.metadata.is_a?(Hash))
      end

      test 'upload Video: mp4' do
        file_name = 'test.mp4'
        upload_video file_name

        assert_equal('mov', @video.metadata.dig('format', 'format_name')&.split(',')&.first)
        assert_equal('video/mp4', @video.content_type)

        validate_video file_name
      end

      test 'upload invalid Video: .pdf' do
        file_name = 'test.pdf'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'pdf', file_name)
        @video = DataCycleCore::Video.new(file: File.open(file_path))
        @video.save

        assert_not(@video.persisted?)
        assert_not(@video.valid?)
        assert(@video.errors.present?)
      end

      def teardown
        # @video.remove_file!
        # @video.destroy!
        # DataCycleCore::VideoUploader.enable_processing = false
      end
    end
  end
end
