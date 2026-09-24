# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class ImageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        teardown do
          subject.instance_variable_set(:@remote_images, nil)
        end

        def subject
          DataCycleCore::Utility::Compute::Image
        end

        def image_double(orientation)
          struct_double(metadata: { 'Orientation' => orientation, 'ImageWidth' => 1920, 'ImageHeight' => 1080 }, file_size: 54_321)
        end

        # Compute::Base resolves both from one hash, so a url reaching only one of them would test
        # a combination that cannot occur: file_format reads data_hash, remote_value the parameters.
        def compute_file_format(url)
          content = Class.new {
            def content_url = nil
            def file_format = nil
            def template_name = 'Bild'
          }.new

          subject.file_format(
            computed_parameters: { 'content_url' => url },
            data_hash: { 'content_url' => url },
            content:,
            key: 'file_format'
          )
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

          DataCycleCore::Concept.stub(:ids_for_tree_with_name, ['ratio-id']) do
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

        test 'file_format asks FastImage for a url whose path carries no extension' do
          DataCycleCore::Asset.stub(:find_by, nil) do
            FastImage.stub(:new, struct_double(type: :png)) do
              value = compute_file_format('https://cms.test/o/adaptive-media/image/197087233/Preview-1280x0/image')

              assert_equal('image/png', value)
            end
          end
        end

        test 'file_format answers from the url extension without reaching FastImage' do
          raising_fast_image = ->(*) { raise('FastImage must not be asked when the url carries the extension') }

          DataCycleCore::Asset.stub(:find_by, nil) do
            FastImage.stub(:new, raising_fast_image) do
              assert_equal('image/jpeg', compute_file_format('https://cdn.test/photo.jpg'))
            end
          end
        end

        test 'the remote computes of one content share a single FastImage request' do
          requested = 0
          counting_fast_image = lambda do |*|
            requested += 1
            struct_double(size: [800, 600], content_length: 4096, type: :png)
          end
          content = Class.new {
            def content_url = nil
            def width = nil
            def height = nil
            def content_size = nil
            def file_format = nil
            def template_name = 'Bild'
          }.new
          params = { 'content_url' => 'https://cms.test/o/adaptive-media/image/1/Preview-1280x0/image' }

          DataCycleCore::Image.stub(:find_by, nil) do
            DataCycleCore::Asset.stub(:find_by, nil) do
              FastImage.stub(:new, counting_fast_image) do
                subject.width(computed_parameters: params, data_hash: params, content:, key: 'width')
                subject.height(computed_parameters: params, data_hash: params, content:, key: 'height')
                subject.file_size(computed_parameters: params, data_hash: params, content:, key: 'content_size')
                subject.file_format(computed_parameters: params, data_hash: params, content:, key: 'file_format')
              end
            end
          end

          assert_equal(1, requested)
        end

        test 'remote_image evicts the oldest url once REMOTE_IMAGE_CACHE_SIZE urls are held' do
          requested = []
          urls = Array.new(subject::REMOTE_IMAGE_CACHE_SIZE + 1) { |i| "https://cdn.test/#{i}.jpg" }

          FastImage.stub(:new, ->(url) { requested << url }) do
            urls.each { |url| subject.remote_image(url) }
            subject.remote_image(urls.last)
            subject.remote_image(urls.first)
          end

          assert_equal(subject::REMOTE_IMAGE_CACHE_SIZE + 2, requested.size)
          assert_equal(urls.first, requested.last)
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
