# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class MergeDuplicateJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'perform merges the duplicate into the original and records the acting user' do
      user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      original = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Job Ziel' })
      duplicate = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Job Duplikat' })
      poi = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Job POI', image: [duplicate.id] })

      DataCycleCore::MergeDuplicateJob.perform_now(original.id, duplicate.id, user.id)

      assert_nil DataCycleCore::Thing.find_by(id: duplicate.id)
      assert_equal [original.id], poi.image.reload.pluck(:id)
      assert_equal user.id, DataCycleCore::Thing::History.where(thing_id: duplicate.id).where.not(deleted_at: nil).first&.deleted_by
    end

    test 'perform works without an acting user' do
      original = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Job Ziel ohne User' })
      duplicate = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Job Duplikat ohne User' })

      DataCycleCore::MergeDuplicateJob.perform_now(original.id, duplicate.id)

      assert_nil DataCycleCore::Thing.find_by(id: duplicate.id)
      assert_nil DataCycleCore::Thing::History.where(thing_id: duplicate.id).where.not(deleted_at: nil).first&.deleted_by
    end

    test 'perform ignores blank ids and contents that no longer exist' do
      original = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Job Ziel unverändert' })

      assert_nil DataCycleCore::MergeDuplicateJob.perform_now(original.id, nil)
      assert_nil DataCycleCore::MergeDuplicateJob.perform_now(nil, original.id)
      assert_not DataCycleCore::MergeDuplicateJob.perform_now(original.id, SecureRandom.uuid)

      assert_predicate DataCycleCore::Thing.find_by(id: original.id), :present?
    end
  end
end
