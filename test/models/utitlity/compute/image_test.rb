# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class ImageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Image
        end

        def image_double(orientation)
          struct_double(metadata: { 'Orientation' => orientation, 'ImageWidth' => 1920, 'ImageHeight' => 1080 }, file_size: 54_321)
        end

        test 'local width and height use exif dimensions for a normal orientation' do
          DataCycleCore::Image.stub(:find_by, image_double('Horizontal (normal)')) do
            params = { 'asset' => SecureRandom.uuid }

            assert_equal(1920, subject.width(computed_parameters: params, data_hash: {}, content: nil, key: 'width'))
            assert_equal(1080, subject.height(computed_parameters: params, data_hash: {}, content: nil, key: 'height'))
          end
        end

        test 'local width and height swap dimensions for a rotated orientation' do
          DataCycleCore::Image.stub(:find_by, image_double('Rotate 90 CW')) do
            params = { 'asset' => SecureRandom.uuid }

            assert_equal(1080, subject.width(computed_parameters: params, data_hash: {}, content: nil, key: 'width'))
            assert_equal(1920, subject.height(computed_parameters: params, data_hash: {}, content: nil, key: 'height'))
          end
        end

        test 'local file size reads the asset file size' do
          DataCycleCore::Image.stub(:find_by, image_double('Horizontal (normal)')) do
            value = subject.file_size(computed_parameters: { 'asset' => SecureRandom.uuid }, data_hash: {}, content: nil, key: 'file_size')

            assert_equal(54_321, value)
          end
        end

        test 'aspect_ratio divides width by height' do
          value = subject.aspect_ratio(computed_parameters: { 'width' => 1920, 'height' => 1080 })

          assert_in_delta(1.7777, value, 0.001)
        end

        test 'aspect_ratio_classification maps ratios above the threshold to classifications' do
          definition = { 'tree_label' => 'Seitenverhältnis', 'compute' => { 'min_values' => [{ '16:9' => 1.7 }, { '4:3' => 1.3 }] } }

          DataCycleCore::ClassificationAlias.stub(:classifications_for_tree_with_name, ['ratio-id']) do
            value = subject.aspect_ratio_classification(computed_parameters: { 'aspect_ratio' => 1.78 }, computed_definition: definition)

            assert_equal(['ratio-id'], value)
          end
        end

        test 'aspect_ratio_classification returns nil when nothing matches the thresholds' do
          definition = { 'tree_label' => 'Seitenverhältnis', 'compute' => { 'min_values' => [{ '16:9' => 1.7 }] } }

          assert_nil(subject.aspect_ratio_classification(computed_parameters: { 'aspect_ratio' => 1.0 }, computed_definition: definition))
        end

        test 'aspect_ratio_classification returns nil for blank parameters or thresholds' do
          assert_nil(subject.aspect_ratio_classification(computed_parameters: {}, computed_definition: { 'compute' => { 'min_values' => [{ '16:9' => 1.7 }] } }))
          assert_nil(subject.aspect_ratio_classification(computed_parameters: { 'aspect_ratio' => 1.78 }, computed_definition: { 'compute' => {} }))
        end

        test 'remote width, height and file size fetch from FastImage when no local asset exists' do
          fast_image = struct_double(size: [800, 600], content_length: 4096)
          content = Class.new {
            def image_url = nil
            def width = nil
            def height = nil
            def file_size = nil
          }.new

          DataCycleCore::Image.stub(:find_by, nil) do
            FastImage.stub(:new, fast_image) do
              params = { 'image_url' => 'https://cdn.test/photo.jpg' }

              assert_equal(800, subject.width(computed_parameters: params, data_hash: {}, content:, key: 'width'))
              assert_equal(600, subject.height(computed_parameters: params, data_hash: {}, content:, key: 'height'))
              assert_equal(4096, subject.file_size(computed_parameters: params, data_hash: {}, content:, key: 'file_size'))
            end
          end
        end

        test 'remote_value returns the stored data_hash value when present' do
          content = Class.new {
            def image_url = nil
            def width = nil
          }.new

          DataCycleCore::Image.stub(:find_by, nil) do
            value = subject.width(computed_parameters: { 'image_url' => 'https://cdn.test/photo.jpg' }, data_hash: { 'width' => 555 }, content:, key: 'width')

            assert_equal(555, value)
          end
        end

        test 'remote_value keeps the old value when the url is unchanged' do
          content = Class.new {
            def image_url = 'https://cdn.test/photo.jpg'
            def width = 999
          }.new

          DataCycleCore::Image.stub(:find_by, nil) do
            value = subject.width(computed_parameters: { 'image_url' => 'https://cdn.test/photo.jpg' }, data_hash: {}, content:, key: 'width')

            assert_equal(999, value)
          end
        end

        test 'remote_value returns nil when no url parameter is present' do
          content = Class.new { def width = nil }.new

          DataCycleCore::Image.stub(:find_by, nil) do
            assert_nil(subject.width(computed_parameters: { 'size' => 123 }, data_hash: {}, content:, key: 'width'))
          end
        end
      end
    end
  end
end
