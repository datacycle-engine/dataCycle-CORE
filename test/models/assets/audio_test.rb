# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class AudioTest < ActiveSupport::TestCase
      def setup
        DataCycleCore::AudioUploader.enable_processing = true
        @audio_temp = DataCycleCore::Audio.count
      end

      def upload_audio(file_name)
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'audio', file_name)
        @audio = DataCycleCore::Audio.new(file: File.open(file_path))
        @audio.save

        assert(@audio.persisted?)
        assert(@audio.valid?)

        @audio.reload
      end

      def validate_audio(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Audio.count)
        # check audio data
        assert(@audio.file_size.positive?)
        assert_equal(file_name, @audio.name)
        assert_equal('DataCycleCore::Audio', @audio.type)
        assert(@audio.metadata.is_a?(Hash))
      end

      test 'upload Audio: mp3' do
        file_name = 'test.mp3'
        upload_audio file_name

        assert_equal('audio/mpeg', @audio.content_type)

        validate_audio file_name
      end

      test 'upload invalid Audio: .pdf' do
        file_name = 'test.pdf'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'pdf', file_name)
        @audio = DataCycleCore::Audio.new(file: File.open(file_path))
        @audio.save

        assert_not(@audio.persisted?)
        assert_not(@audio.valid?)
        assert(@audio.errors.present?)
      end

      def teardown
        @audio.remove_file!
        @audio.destroy!
        DataCycleCore::AudioUploader.enable_processing = false
      end
    end
  end
end
