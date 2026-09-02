# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Storage
    module Previewer
      # Coverage for the custom ActiveStorage previewers. The blob download and the
      # external mutool/ffmpeg `draw` calls are stubbed to yield in-memory doubles, so
      # the argument-building and frame/option logic runs without a real asset binary.
      class PreviewerCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        # --- VideoPreviewer -------------------------------------------------
        test 'VideoPreviewer#preview streams a jpeg frame for the blob' do
          filename = Object.new
          filename.define_singleton_method(:base) { 'clip' }
          blob = Object.new
          blob.define_singleton_method(:filename) { filename }
          blob.define_singleton_method(:attachments) { [] }

          previewer = DataCycleCore::Storage::Previewer::VideoPreviewer.new(blob)

          input = Object.new
          input.define_singleton_method(:path) { '/tmp/in.mp4' }
          output = Object.new
          yielded = nil

          previewer.stub(:download_blob_to_tempfile, ->(&block) { block.call(input) }) do
            previewer.stub(:draw, ->(*, &block) { block.call(output) }) do
              previewer.preview { |**kwargs| yielded = kwargs }
            end
          end

          assert_equal 'clip.jpg', yielded[:filename]
          assert_equal 'image/jpeg', yielded[:content_type]
        end

        test 'VideoPreviewer#video_options_from_thing builds a seek argument from the start time' do
          thing = Object.new
          thing.define_singleton_method(:try) { |method| method == :preview_image_start_time ? 5 : nil }
          thing.define_singleton_method(:duration) { 100 }
          record = Object.new
          record.define_singleton_method(:thing) { thing }
          attachment = Object.new
          attachment.define_singleton_method(:record) { record }
          blob = Object.new
          blob.define_singleton_method(:attachments) { [attachment] }

          previewer = DataCycleCore::Storage::Previewer::VideoPreviewer.new(blob)

          assert_equal ' -ss 00:00:05', previewer.send(:video_options_from_thing)
        end

        # --- MuPdfPreviewer -------------------------------------------------
        test 'MuPdfPreviewer#transformed_previewer_options maps configured options' do
          previewer = DataCycleCore::Storage::Previewer::MuPdfPreviewer.new(Object.new)

          DataCycleCore::Feature::CustomAssetPreviewer.stub(:enabled?, false) do
            assert_empty previewer.send(:transformed_previewer_options)
          end

          DataCycleCore::Feature::CustomAssetPreviewer.stub(:enabled?, true) do
            DataCycleCore::Feature::CustomAssetPreviewer.stub(:previewer_options, ->(*) { {} }) do
              assert_empty previewer.send(:transformed_previewer_options)
            end

            DataCycleCore::Feature::CustomAssetPreviewer.stub(:previewer_options, ->(*) { { resolution: 150, width: 100 } }) do
              assert_equal ['-r', '150', '-w', '100'], previewer.send(:transformed_previewer_options)
            end
          end
        end

        test 'MuPdfPreviewer#draw_first_page_from calls mutool with the file path' do
          previewer = DataCycleCore::Storage::Previewer::MuPdfPreviewer.new(Object.new)
          file = Object.new
          file.define_singleton_method(:path) { '/tmp/doc.pdf' }
          called = false

          DataCycleCore::Feature::CustomAssetPreviewer.stub(:enabled?, false) do
            previewer.stub(:draw, ->(*, &_block) { called = true }) do
              previewer.send(:draw_first_page_from, file)
            end
          end

          assert called
        end
      end
    end
  end
end
