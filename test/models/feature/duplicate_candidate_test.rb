# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DuplicateCandidateTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include ActiveJob::TestHelper

    test 'find duplicates for images' do
      assert DataCycleCore::Feature::DuplicateCandidate.enabled?

      image1 = upload_image('test_rgb.jpeg')
      assert image1.thumb_preview.present?
      content1 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image1.id })

      image2 = upload_image('test_rgb.png')
      assert image2.thumb_preview.present?
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', asset: image2.id })

      image3 = upload_image('test_rgb.gif')
      assert image3.thumb_preview.present?
      content3 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 3', asset: image3.id })

      image4 = upload_image('test_cmyk.jpeg')
      assert image4.thumb_preview.present?
      content4 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 4', asset: image4.id })

      image5 = upload_image('test_rgb_portrait.jpeg')
      assert image5.thumb_preview.present?
      content5 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 5', asset: image5.id })

      assert_empty content1.duplicate_candidates
      assert_empty content2.duplicate_candidates
      assert_empty content3.duplicate_candidates
      assert_empty content4.duplicate_candidates
      assert_empty content5.duplicate_candidates

      DataCycleCore::Thing
        .where(external_source_id: nil, external_key: nil)
        .where.not(content_type: 'embedded')
        .find_each(&:create_duplicate_candidates)

      assert_equal 3, content1.duplicate_candidates.reload.size
      assert_equal 3, content2.duplicate_candidates.reload.size
      assert_equal 3, content3.duplicate_candidates.reload.size
      assert_equal 3, content4.duplicate_candidates.reload.size
      assert_empty content5.duplicate_candidates.reload
      assert_equal [content2.id, content3.id, content4.id].sort, content1.duplicates.pluck(:id).sort
      assert_equal [content1.id, content3.id, content4.id].sort, content2.duplicates.pluck(:id).sort
      assert_equal [content1.id, content2.id, content4.id].sort, content3.duplicates.pluck(:id).sort
      assert_equal [content1.id, content2.id, content3.id].sort, content4.duplicates.pluck(:id).sort
    end

    test 'merge with duplicate' do
      assert DataCycleCore::Feature::DuplicateCandidate.enabled?

      image1 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
      image2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2' })
      image3 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 3' })

      content1 = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Test Artikel 1', image: [image2.id, image3.id], primary_image: [image2.id], logo: [image2.id, image3.id] })
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Test Artikel 2', image: [image1.id, image2.id], primary_image: [image1.id], logo: [image1.id, image2.id] })
      content3 = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Test Artikel 3', image: [image1.id], primary_image: [image2.id], logo: [image2.id] })

      content1.set_data_hash(data_hash: { name: 'TestArtikel 1' }.deep_stringify_keys, partial_update: true)
      content2.set_data_hash(data_hash: { name: 'TestArtikel 2' }.deep_stringify_keys, partial_update: true)
      content3.set_data_hash(data_hash: { name: 'TestArtikel 2' }.deep_stringify_keys, partial_update: true)

      image1.merge_with_duplicate(image2)

      assert_nil DataCycleCore::Thing.find_by(id: image2.id)

      # FIXME: Destroying a content removes content_relations in the history entries
      assert_equal [image1.id, image3.id], content1.image.pluck(:id)
      assert_equal [image1.id], content1.primary_image.pluck(:id)
      assert_equal [image1.id, image3.id], content1.logo.pluck(:id)
      # assert_equal [image1.id, image3.id], content1.histories.first.image.pluck(:id)
      # assert_equal [image1.id], content1.histories.first.primary_image.pluck(:id)
      # assert_equal [image1.id, image3.id], content1.histories.first.logo.pluck(:id)

      assert_equal [image1.id], content2.image.pluck(:id)
      assert_equal [image1.id], content2.primary_image.pluck(:id)
      assert_equal [image1.id], content2.logo.pluck(:id)
      # assert_equal [image1.id], content2.histories.first.image.pluck(:id)
      # assert_equal [image1.id], content2.histories.first.primary_image.pluck(:id)
      # assert_equal [image1.id], content2.histories.first.logo.pluck(:id)

      assert_equal [image1.id], content3.image.pluck(:id)
      assert_equal [image1.id], content3.primary_image.pluck(:id)
      assert_equal [image1.id], content3.logo.pluck(:id)
      # assert_equal [image1.id], content3.histories.first.image.pluck(:id)
      # assert_equal [image1.id], content3.histories.first.primary_image.pluck(:id)
      # assert_equal [image1.id], content3.histories.first.logo.pluck(:id)
    end

    test 'duplicates marked as false_positive are not shown as duplicates' do
      image1 = upload_image('test_rgb.jpeg')
      assert image1.thumb_preview.present?
      content1 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image1.id })

      image2 = upload_image('test_rgb.png')
      assert image2.thumb_preview.present?
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', asset: image2.id })

      assert_empty content1.duplicate_candidates
      assert_empty content2.duplicate_candidates

      DataCycleCore::Thing
        .where(external_source_id: nil, external_key: nil)
        .where.not(content_type: 'embedded')
        .find_each(&:create_duplicate_candidates)

      assert_equal 1, content1.duplicate_candidates.reload.size
      assert_equal 1, content2.duplicate_candidates.reload.size

      DataCycleCore::ThingDuplicate
        .find(content2.duplicate_candidates.with_fp.find_by(duplicate_id: content1.id).thing_duplicate_id)
        .update!(false_positive: true)

      assert_empty content1.duplicate_candidates.reload
      assert_empty content2.duplicate_candidates.reload
    end

    test 'duplicates from different external_source get merged correctly' do
      external_source_f = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      external_key_f = SecureRandom.uuid
      external_source_oa = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      external_key_oa = SecureRandom.uuid
      external_source_v = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-2')
      external_key_v = SecureRandom.uuid
      external_source_m = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-3')
      external_key_m = SecureRandom.uuid
      external_source_hrs = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-4')
      external_key_hrs = SecureRandom.uuid

      image_f = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
      image_f.update_columns(external_source_id: external_source_f.id, external_key: external_key_f)
      image_f.external_system_syncs.find_or_create_by!(external_system_id: external_source_v.id, external_key: external_key_v, sync_type: 'duplicate')

      image_oa = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2' })
      image_oa.update_columns(external_source_id: external_source_oa.id, external_key: external_key_oa)
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_v.id, external_key: external_key_v, sync_type: 'duplicate')
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_m.id, external_key: external_key_m, sync_type: 'link')
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_hrs.id, external_key: external_key_hrs, sync_type: 'export')
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_f.id, external_key: external_key_f, sync_type: 'duplicate')
      image_oa.external_system_syncs.find_or_create_by!(external_system_id: external_source_f.id, external_key: external_key_v, sync_type: 'link')

      image_f.merge_with_duplicate(image_oa)

      assert_nil DataCycleCore::Thing.find_by(id: image_oa.id)

      assert_equal external_source_f.id, image_f.external_source.id
      assert_equal 6, image_f.external_system_syncs.size
      assert_equal 6, image_f.external_system_syncs.where(sync_type: 'duplicate').size
      assert_equal 0, image_f.external_system_syncs.where(sync_type: 'link').size
      assert_equal 0, image_f.external_system_syncs.where(sync_type: 'export').size
    end
  end
end
