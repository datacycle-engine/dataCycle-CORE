# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for DataCycleCore::Image: version variants, validators and helpers.
  class ImageCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @image = upload_image('test_rgb.jpeg')
    end

    def image_path(name)
      File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', name)
    end

    def failing_file
      Class.new {
        def attached? = true
        def variant(*) = raise('variant generation failed')
      }.new
    end

    test 'version helpers generate variants for an attached file' do
      assert_not_nil @image.thumb_preview
      assert_not_nil @image.web
      assert_not_nil @image.default
      assert_not_nil @image.dynamic({ 'width' => 50, 'height' => 50 })
      assert_not_nil @image.dynamic({})
    end

    test 'version helpers instrument and return nil when variant generation fails' do
      @image.stub(:file, failing_file) do
        assert_nil @image.thumb_preview
        assert_nil @image.web
        assert_nil @image.default
        assert_nil @image.dynamic({ 'width' => 50 })
      end
    end

    test 'format_for_transformation falls back to the default mime type' do
      @image.stub(:content_type, 'image/tiff') do
        assert_equal('jpeg', @image.send(:format_for_transformation))
      end
    end

    test 'duplicate_candidates are empty without a phash' do
      fresh = DataCycleCore::Image.find(@image.id)

      fresh.stub(:duplicate_check, {}) do
        assert_empty fresh.duplicate_candidates
        assert_empty fresh.duplicate_candidates_with_score
      end
    end

    test 'metadata_from_blob returns an empty hash when there is no pending attachment' do
      assert_equal({}, @image.send(:metadata_from_blob))
    end

    test 'resolution_validation flags images outside the configured resolution' do
      max_errors = DataCycleCore::Image.find(@image.id)
      max_errors.resolution_validation({ max: 1 })

      assert_predicate max_errors.errors[:file], :present?

      min_errors = DataCycleCore::Image.find(@image.id)
      min_errors.resolution_validation({ min: 999_999_999 })

      assert_predicate min_errors.errors[:file], :present?
    end

    test 'resolution_validation reads the tempfile of a pending upload' do
      new_image = DataCycleCore::Image.new
      new_image.file.attach(io: File.open(image_path('test_rgb.jpeg')), filename: 'test_rgb.jpeg')
      new_image.resolution_validation({ max: 1 })

      assert_predicate new_image.errors[:file], :present?
    end

    test 'resolution_validation reads the tempfile of an uploaded file' do
      uploaded = Rack::Test::UploadedFile.new(image_path('test_rgb.jpeg'), 'image/jpeg')
      new_image = DataCycleCore::Image.new
      new_image.file.attach(uploaded)
      new_image.resolution_validation({ max: 1 })

      assert_predicate new_image.errors[:file], :present?
    end

    test 'resolution_validation rescues unreadable files' do
      Vips::Image.stub(:vipsload, ->(*) { raise 'broken image' }) do
        broken = DataCycleCore::Image.find(@image.id)
        broken.resolution_validation({ max: 1 })

        assert_predicate broken.errors[:file], :present?
      end
    end

    test 'dimensions_validation flags a landscape image below the minimum bounds' do
      image = DataCycleCore::Image.find(@image.id)
      image.dimensions_validation({
        'jpeg' => { max: { width: 1, height: 1 } },
        landscape: { min: { width: 999_999, height: 999_999 } }
      })

      assert_predicate image.errors[:file], :present?
    end

    test 'dimensions_validation flags a portrait image below the minimum bounds' do
      portrait = upload_image('test_rgb_portrait.jpeg')
      portrait.dimensions_validation({ portrait: { min: { width: 999_999, height: 999_999 } } })

      assert_predicate portrait.errors[:file], :present?
    end

    test 'dimensions_validation rescues unreadable files' do
      Vips::Image.stub(:vipsload, ->(*) { raise 'broken image' }) do
        broken = DataCycleCore::Image.find(@image.id)
        broken.dimensions_validation({ landscape: { min: { width: 1 } } })

        assert_predicate broken.errors[:file], :present?
      end
    end
  end
end
