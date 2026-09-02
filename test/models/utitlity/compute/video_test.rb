# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class VideoTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Video
        end

        def video_meta
          struct_double(metadata: {
            'streams' => [{ 'width' => 1920, 'height' => 1080 }],
            'format' => { 'duration' => '12.5' }
          })
        end

        test 'meta_value reads a nested metadata path' do
          DataCycleCore::Video.stub(:find_by, video_meta) do
            assert_equal('12.5', subject.meta_value('video-id', ['format', 'duration']))
          end
        end

        test 'meta_value returns nil for a missing video' do
          DataCycleCore::Video.stub(:find_by, nil) do
            assert_nil(subject.meta_value('missing', ['format', 'duration']))
          end
        end

        test 'meta_stream_value reads from the first stream' do
          DataCycleCore::Video.stub(:find_by, video_meta) do
            assert_equal(1920, subject.meta_stream_value('video-id', ['width']))
          end
        end

        test 'width, height and duration derive from the stream metadata' do
          DataCycleCore::Video.stub(:find_by, video_meta) do
            params = { 'asset' => 'video-id' }

            assert_equal(1920, subject.width(content: video_content, computed_parameters: params))
            assert_equal(1080, subject.height(content: video_content, computed_parameters: params))
            assert_in_delta(12.5, subject.duration(content: video_content, computed_parameters: params))
          end
        end

        test 'preview_image_start_time returns nil when no asset is given' do
          assert_nil(subject.preview_image_start_time(computed_parameters: { 'asset' => nil }))
        end

        test 'preview_image_start_time purges the preview image of the video blob' do
          purgeable = Class.new { def purge = :purged }.new
          video = struct_double(file: struct_double(blob: struct_double(preview_image: purgeable)))

          DataCycleCore::Video.stub(:find_by, video) do
            assert_equal(:purged, subject.preview_image_start_time(computed_parameters: { 'asset' => 'video-id' }))
          end
        end

        test 'transcode keeps an existing transcoded value' do
          content = Class.new {
            def video = 'https://cdn.test/existing.mp4'
            def id = 'content-id'
          }.new

          value = subject.transcode(content:, key: 'video', computed_parameters: { 'asset' => 'asset-id' })

          assert_equal('https://cdn.test/existing.mp4', value)
        end

        test 'transcode enqueues a transcoding job and returns the placeholder' do
          content = Class.new { def id = 'content-id' }.new

          DataCycleCore::VideoTranscodingJob.stub(:perform_later, nil) do
            value = subject.transcode(content:, key: 'video', computed_parameters: { 'asset' => 'asset-id' })

            assert_equal(DataCycleCore::Feature::VideoTranscoding.placeholder, value)
          end
        end

        test 'transcode returns nil when there is no asset to transcode' do
          content = Class.new { def id = 'content-id' }.new

          assert_nil(subject.transcode(content:, key: 'video', computed_parameters: {}))
        end

        test 'preview_url returns the linked thumbnail when present' do
          value = subject.preview_url(
            content: video_content,
            key: 'preview_image',
            computed_parameters: { 'asset' => 'video-id', 'thumbnail_image' => [{ 'content_url' => 'https://cdn.test/thumb.jpg' }] },
            computed_definition: { 'compute' => { 'parameters' => ['thumbnail_image.content_url'] } }
          )

          assert_equal('https://cdn.test/thumb.jpg', value)
        end

        test 'thumbnail_url returns nil when there is no thumbnail and the video is not attached' do
          DataCycleCore::Video.stub(:find_by, unattached_asset_double) do
            value = subject.thumbnail_url(
              content: video_content,
              key: 'preview_image',
              computed_parameters: { 'asset' => 'video-id' },
              computed_definition: { 'compute' => { 'parameters' => [] } }
            )

            assert_nil(value)
          end
        end

        test 'preview_url returns the processed preview url for an attached video' do
          DataCycleCore::Video.stub(:find_by, attached_asset_double(url: 'https://cdn.test/preview.png')) do
            DataCycleCore::ActiveStorageService.stub(:with_current_options, ->(&block) { block.call }) do
              value = subject.preview_url(
                content: video_content,
                key: 'preview_image',
                computed_parameters: { 'asset' => 'video-id' },
                computed_definition: { 'compute' => { 'parameters' => [] } }
              )

              assert_equal('https://cdn.test/preview.png', value)
            end
          end
        end

        test 'thumbnail_url returns the processed resized url for an attached video' do
          DataCycleCore::Video.stub(:find_by, attached_asset_double(url: 'https://cdn.test/thumb.png')) do
            DataCycleCore::ActiveStorageService.stub(:with_current_options, ->(&block) { block.call }) do
              value = subject.thumbnail_url(
                content: video_content,
                key: 'preview_image',
                computed_parameters: { 'asset' => 'video-id' },
                computed_definition: { 'compute' => { 'parameters' => [] } }
              )

              assert_equal('https://cdn.test/thumb.png', value)
            end
          end
        end

        test 'preview_url and thumbnail_url rescue ActiveStorage errors and return nil' do
          DataCycleCore::Video.stub(:find_by, attached_asset_double(raises: true)) do
            DataCycleCore::ActiveStorageService.stub(:with_current_options, ->(&block) { block.call }) do
              base = { content: video_content, key: 'preview_image', computed_parameters: { 'asset' => 'video-id' }, computed_definition: { 'compute' => { 'parameters' => [] } } }

              assert_nil(subject.preview_url(**base))
              assert_nil(subject.thumbnail_url(**base))
            end
          end
        end

        private

        def video_content
          asset_content_double
        end
      end
    end
  end
end
