# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class ImageTest < ActiveSupport::TestCase
      def setup
        @image_temp = DataCycleCore::Image.count
      end

      def upload_image(file_name)
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @image = DataCycleCore::Image.new(file: File.open(file_path))
        @image.save

        assert(@image.persisted?)
        assert(@image.valid?)

        @image.reload
      end

      def validate_image(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Image.count)
        # check image data
        assert(@image.file_size.positive?)
        assert_equal(file_name, @image.name)
        assert_equal('DataCycleCore::Image', @image.type)
        assert(@image.metadata.is_a?(Hash))
        assert(@image.duplicate_check.dig('phash').positive?)
      end

      test 'upload Image: rgb/jpg' do
        file_name = 'test_rgb.jpg'
        upload_image file_name

        assert_equal('sRGB', @image.metadata.dig('colorspace'))
        assert_equal('image/jpeg', @image.content_type)

        validate_image file_name
      end

      test 'upload Image: rgb/gif' do
        file_name = 'test_rgb.gif'
        upload_image file_name

        assert_equal('image/gif', @image.content_type)
        assert_equal('sRGB', @image.metadata.dig('colorspace'))

        validate_image file_name
      end

      test 'upload Image: rgb/png' do
        file_name = 'test_rgb.png'
        upload_image file_name

        assert_equal('image/png', @image.content_type)
        assert_equal('sRGB', @image.metadata.dig('colorspace'))

        validate_image file_name
      end

      test 'upload Image: cmyk/jpg' do
        file_name = 'test_cmyk.jpg'
        upload_image file_name

        assert_equal('image/jpeg', @image.content_type)
        assert_equal('CMYK', @image.metadata.dig('colorspace'))

        validate_image file_name
      end

      test 'upload invalid Image: .pdf' do
        file_name = 'test.pdf'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'pdf', file_name)
        @image = DataCycleCore::Image.new(file: File.open(file_path))
        @image.save

        assert_not(@image.persisted?)
        assert_not(@image.valid?)
        assert_equal(@image.errors.size, 2)
      end
    end
  end
end
