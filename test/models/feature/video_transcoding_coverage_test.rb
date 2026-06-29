# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for the VideoTranscoding feature: config, processable?, the private
    # video_filename builder and the full process_video pipeline. enabled?/config
    # and FFMPEG are stubbed so the filename + path building and the transcode call
    # run over lightweight doubles without a real feature config, blob or ffmpeg.
    class VideoTranscodingCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Feature::VideoTranscoding

      def asset_double(name:, video_path: '/tmp/video.mov')
        video = Object.new
        video.define_singleton_method(:path) { video_path }
        blob = Object.new
        blob.define_singleton_method(:open) { |&blk| blk.call(video) }
        file = Object.new
        file.define_singleton_method(:blob) { blob }
        asset = Object.new
        asset.define_singleton_method(:name) { name }
        asset.define_singleton_method(:file) { file }
        asset
      end

      def thing_double(asset:, id: 'vid-1')
        obj = Object.new
        obj.define_singleton_method(:is_a?) { |klass| klass == DataCycleCore::Thing || Kernel.instance_method(:is_a?).bind_call(self, klass) }
        obj.define_singleton_method(:asset) { asset }
        obj.define_singleton_method(:id) { id }
        obj
      end

      test 'config reads the feature configuration' do
        DataCycleCore.stub(:features, { video_transcoding: { config: { 'mp4' => {} } } }) do
          assert_equal({ 'mp4' => {} }, Subject.config)
        end
      end

      test 'processable? requires enabled, a Thing, a configured variant and an asset' do
        Subject.stub(:config, { 'mp4' => {} }) do
          Subject.stub(:enabled?, true) do
            assert(Subject.processable?(content: thing_double(asset: Object.new), variant: 'mp4'))
            assert_not(Subject.processable?(content: thing_double(asset: Object.new), variant: 'webm'))
            assert_not(Subject.processable?(content: thing_double(asset: nil), variant: 'mp4'))
          end

          Subject.stub(:enabled?, false) do
            assert_not(Subject.processable?(content: thing_double(asset: Object.new), variant: 'mp4'))
          end
        end
      end

      test 'video_filename parameterizes the name with append and extension' do
        content = thing_double(asset: asset_double(name: 'My Video.MOV'))

        result = Subject.send(:video_filename, content, { 'filename_append' => 'web', 'file_ext' => 'mp4' })

        assert_equal('my_video-web.mp4', result)
      end

      test 'video_filename keeps an extensionless name and omits a blank append' do
        content = thing_double(asset: asset_double(name: 'clip'))

        result = Subject.send(:video_filename, content, { 'file_ext' => 'webm' })

        assert_equal('clip.webm', result)
      end

      test 'process_video transcodes and returns the processed asset url' do
        content = thing_double(asset: asset_double(name: 'My Video.mov'))
        config = { 'mp4' => { 'processing' => { 'options' => { '-y' => true }, 'filename_append' => 'web', 'file_ext' => 'mp4' } } }
        movie = Object.new
        movie.define_singleton_method(:transcode) { |*_args| true }

        Subject.stub(:processable?, true) do
          Subject.stub(:config, config) do
            FileUtils.stub(:mkdir_p, nil) do
              FFMPEG::Movie.stub(:new, movie) do
                url = Subject.process_video(content:, variant: 'mp4')

                assert_includes(url, 'processed/video/vid-1')
                assert(url.end_with?('my_video-web.mp4'))
              end
            end
          end
        end
      end

      test 'process_video returns nil when the content is not processable' do
        Subject.stub(:processable?, false) do
          assert_nil(Subject.process_video(content: Object.new, variant: 'mp4'))
        end
      end
    end
  end
end
