# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class VideoTest < ActiveSupport::TestCase
      include DataCycleCore::ActiveStorageHelper

      def setup
        @video_temp = DataCycleCore::Video.count
      end

      def validate_video(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Video.count)
        # check video data
        assert_predicate(@video.file_size, :positive?)
        assert_equal(file_name, @video.name)
        assert_equal('DataCycleCore::Video', @video.type)
        assert(@video.metadata.is_a?(Hash))
      end

      test 'upload Video: mp4' do
        file_name = 'test.mp4'
        @video = upload_video(file_name)

        assert_equal('mov', @video.metadata.dig('format', 'format_name')&.split(',')&.first)
        assert_equal('video/mp4', @video.content_type)

        validate_video file_name
      end

      test 'upload invalid Video: .pdf' do
        file_name = 'test.pdf'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'pdf', file_name)
        @video = DataCycleCore::Video.new
        @video.file.attach(io: File.open(file_path), filename: file_name)
        @video.save

        assert_not(@video.persisted?)
        assert_not(@video.valid?)
        assert_predicate(@video.errors, :present?)
      end

      test 'custom_validators dispatches to the configured per-validator methods' do
        DataCycleCore.stub(:uploader_validations, { 'video' => { 'foo' => {} } }) do
          assert_nothing_raised { DataCycleCore::Video.new.custom_validators }
        end
      end

      test 'validate_video_codec adds an error when the codec is excluded' do
        movie = Object.new
        movie.define_singleton_method(:video_codec) { 'h264' }
        video = DataCycleCore::Video.new

        video.send(:validate_video_codec, movie, { video: ['vp9'] })

        assert_predicate(video.errors, :present?)
      end

      test 'validate_audio_codec adds an error when the codec is excluded' do
        movie = Object.new
        movie.define_singleton_method(:audio_codec) { 'aac' }
        video = DataCycleCore::Video.new

        video.send(:validate_audio_codec, movie, { audio: ['opus'] })

        assert_predicate(video.errors, :present?)
      end
    end
  end
end
