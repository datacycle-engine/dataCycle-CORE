# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class ImageTest < ActiveSupport::TestCase
      def setup
        @image_temp = DataCycleCore::Image.count
      end

      test 'validates Image: rgb/jpg' do
        file_name = 'test_rgb.jpg'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @image = DataCycleCore::Image.new(file: File.open(file_path))
        @image.save

        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Image.count)

        # check image data
        assert(@image.file_size.positive?)
        assert_equal(file_name, @image.name)
        assert_equal('image/jpeg', @image.content_type)
        assert_equal('DataCycleCore::Image', @image.type)
        assert_equal('sRGB', @image.metadata.dig('colorspace'))
        assert(@image.duplicate_check.dig('phash').positive?)
      end

      test 'validates Image: rgb/gif' do
        file_name = 'test_rgb.gif'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @image = DataCycleCore::Image.new(file: File.open(file_path))
        @image.save

        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Image.count)
        # check image data
        assert(@image.file_size.positive?)
        assert_equal(file_name, @image.name)
        assert_equal('image/gif', @image.content_type)
        assert_equal('DataCycleCore::Image', @image.type)
        assert_equal('sRGB', @image.metadata.dig('colorspace'))
        assert(@image.duplicate_check.dig('phash').positive?)
      end

      test 'validates Image: rgb/png' do
        file_name = 'test_rgb.png'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @image = DataCycleCore::Image.new(file: File.open(file_path))
        @image.save

        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Image.count)
        # check image data
        assert(@image.file_size.positive?)
        assert_equal(file_name, @image.name)
        assert_equal('image/png', @image.content_type)
        assert_equal('DataCycleCore::Image', @image.type)
        assert_equal('sRGB', @image.metadata.dig('colorspace'))
        assert(@image.duplicate_check.dig('phash').zero?)
      end

      test 'validates Image: cmyk/jpg' do
        file_name = 'test_cmyk.jpg'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @image = DataCycleCore::Image.new(file: File.open(file_path))
        @image.save

        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Image.count)
        # check image data
        assert(@image.file_size.positive?)
        assert_equal(file_name, @image.name)
        assert_equal('image/jpeg', @image.content_type)
        assert_equal('DataCycleCore::Image', @image.type)
        assert_equal('CMYK', @image.metadata.dig('colorspace'))
        assert(@image.duplicate_check.dig('phash').zero?)
      end
    end
  end
end
