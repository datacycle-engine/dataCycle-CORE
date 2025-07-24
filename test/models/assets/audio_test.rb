# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class AudioTest < ActiveSupport::TestCase
      include DataCycleCore::ActiveStorageHelper

      def setup
        @audio_temp = DataCycleCore::Audio.count
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
        @audio = upload_audio(file_name)

        assert_equal('audio/mpeg', @audio.content_type)

        validate_audio file_name
      end

      test 'upload invalid Audio: .pdf' do
        file_name = 'test.pdf'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'pdf', file_name)
        @audio = DataCycleCore::Audio.new
        @audio.file.attach(io: File.open(file_path), filename: file_name)
        @audio.save

        assert_not(@audio.persisted?)
        assert_not(@audio.valid?)
        assert(@audio.errors.present?)
      end
    end
  end
end
