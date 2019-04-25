# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DuplicateCandidateTest < ActiveSupport::TestCase
    def setup
      DataCycleCore::ImageUploader.enable_processing = true
    end

    def upload_image(file_name)
      file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
      image = DataCycleCore::Image.new(file: File.open(file_path))
      image.save
      image
    end

    test 'find duplicates for images' do
      assert DataCycleCore::Feature::DuplicateCandidate.enabled?

      image1 = upload_image 'test_rgb.jpg'
      content1 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image1.id })

      image2 = upload_image 'test_rgb.png'
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', asset: image2.id })

      image3 = upload_image 'test_rgb.gif'
      content3 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 3', asset: image3.id })

      image4 = upload_image 'test_cmyk.jpg'
      content4 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 4', asset: image4.id })

      image5 = upload_image 'test_rgb_portrait.jpg'
      content5 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 5', asset: image5.id })

      assert_empty content1.duplicate_candidates
      assert_empty content2.duplicate_candidates
      assert_empty content3.duplicate_candidates
      assert_empty content4.duplicate_candidates
      assert_empty content5.duplicate_candidates

      DataCycleCore::Thing
        .where(template: false, external_source_id: nil, external_key: nil)
        .where.not(content_type: 'embedded')
        .find_each(&:create_duplicate_candidates)

      assert_equal 3, content1.duplicate_candidates.reload.size
      assert_equal 3, content2.duplicate_candidates.reload.size
      assert_equal 3, content3.duplicate_candidates.reload.size
      assert_equal 3, content4.duplicate_candidates.reload.size
      assert_empty content5.duplicate_candidates.reload
      assert_equal [content2.id, content3.id, content4.id].sort, content1.duplicates.ids.sort
      assert_equal [content1.id, content3.id, content4.id].sort, content2.duplicates.ids.sort
      assert_equal [content1.id, content2.id, content4.id].sort, content3.duplicates.ids.sort
      assert_equal [content1.id, content2.id, content3.id].sort, content4.duplicates.ids.sort
    end

    def teardown
      DataCycleCore::ImageUploader.enable_processing = false
    end
  end
end
