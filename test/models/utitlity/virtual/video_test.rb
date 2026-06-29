# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class VideoTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Video
        end

        test 'thumbnail_url generates a preview url from the attached video file' do
          content = video_content(processed_url_double('https://cdn.test/thumb.jpg'))

          DataCycleCore::ActiveStorageService.stub(:with_current_options, ->(&block) { block.call }) do
            assert_equal('https://cdn.test/thumb.jpg', subject.thumbnail_url(virtual_parameters: ['poster'], content:))
          end
        end

        test 'thumbnail_url returns nil when the preview file is missing' do
          processed = Class.new { def url = raise(ActiveStorage::FileNotFoundError) }.new
          content = video_content(processed)

          DataCycleCore::ActiveStorageService.stub(:with_current_options, ->(&block) { block.call }) do
            assert_nil(subject.thumbnail_url(virtual_parameters: ['poster'], content:))
          end
        end

        private

        def processed_url_double(url)
          Struct.new(:url).new(url)
        end

        def video_content(processed)
          preview = Struct.new(:processed).new(processed)
          file = Struct.new(:preview_value) {
            def attached? = true
            def preview(*_args) = preview_value
          }.new(preview)
          asset = Struct.new(:file).new(file)
          Struct.new(:asset) {
            def try(*_args) = nil
          }.new(asset)
        end
      end
    end
  end
end
