# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class ImageTest < ActiveSupport::TestCase
      include DataCycleCore::ActiveStorageHelper
      def setup
        # DataCycleCore::ImageUploader.enable_processing = true
        @image_temp = DataCycleCore::Image.count
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
        file_name = 'test_rgb.jpeg'
        @image = upload_image(file_name)

        assert_equal('sRGB', @image.metadata.dig('ImColorSpace'))
        assert_equal('image/jpeg', @image.content_type)

        validate_image file_name
      end

      test 'upload portrait format Image: rgb/jpg' do
        file_name = 'test_rgb_portrait.jpeg'
        @image = upload_image(file_name)

        assert_equal('sRGB', @image.metadata.dig('ImColorSpace'))
        assert_equal('image/jpeg', @image.content_type)

        validate_image file_name
      end

      test 'upload Image: rgb/gif' do
        file_name = 'test_rgb.gif'
        @image = upload_image(file_name)

        assert_equal('image/gif', @image.content_type)
        assert_equal('sRGB', @image.metadata.dig('ImColorSpace'))

        validate_image file_name
      end

      test 'upload Image: rgb/png' do
        file_name = 'test_rgb.png'
        @image = upload_image(file_name)

        assert_equal('image/png', @image.content_type)
        assert_equal('sRGB', @image.metadata.dig('ImColorSpace'))

        validate_image file_name
      end

      test 'upload Image: cmyk/jpg' do
        file_name = 'test_cmyk.jpeg'
        @image = upload_image(file_name)

        assert_equal('image/jpeg', @image.content_type)
        assert_equal('CMYK', @image.metadata.dig('ImColorSpace'))

        validate_image file_name
      end

      test 'upload invalid Image: .pdf' do
        file_name = 'test.pdf'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'pdf', file_name)
        @image = DataCycleCore::Image.new
        @image.file.attach(io: File.open(file_path), filename: file_name)
        @image.save

        assert_not(@image.persisted?)
        assert_not(@image.valid?)
        assert(@image.errors.present?)
      end

      def teardown
        # return if @image.id.blank?
        # @image.remove_file!
        # DataCycleCore::ImageUploader.enable_processing = false
      end
    end
  end
end
