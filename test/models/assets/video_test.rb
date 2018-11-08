# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class VideoTest < ActiveSupport::TestCase
      def setup
        @video_temp = DataCycleCore::Video.count
      end

      def upload_video(file_name)
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'videos', file_name)
        @video = DataCycleCore::Video.new(file: File.open(file_path))
        @video.save

        assert(@video.persisted?)
        assert(@video.valid?)

        @video.reload
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

      test 'upload Video: mp3' do
        file_name = 'test.mpg'
        upload_video file_name

        assert_equal('mpeg', @video.metadata.dig('format', 'format_name'))
        assert_equal('video/mpeg', @video.content_type)

        validate_video file_name
      end

      test 'upload invalid Video: .pdf' do
        file_name = 'test.pdf'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'pdf', file_name)
        @video = DataCycleCore::Video.new(file: File.open(file_path))
        @video.save

        assert_not(@video.persisted?)
        assert_not(@video.valid?)
        assert_equal(@video.errors.size, 2)
      end
    end
  end
end
