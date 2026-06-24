# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationMappingJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '00000000-0000-0000-0000-000000000000'

    test 'perform returns early when the classification alias is missing' do
      DataCycleCore::ClassificationAlias.stub(:find_by, nil) do
        assert_nil DataCycleCore::ClassificationMappingJob.new.perform(UUID)
      end
    end

    test 'perform broadcasts an unlock when there is nothing to change' do
      classification_alias = DataCycleCore::ClassificationAlias.first
      skip 'no classification alias seeded' if classification_alias.nil?

      broadcasts = []
      # The heavy work happens in a forked child whose coverage is discarded by
      # SimpleCov anyway; stub the fork so the parent-side bookkeeping is exercised
      # without spawning a process or touching the database.
      Process.stub(:fork, ->(&_block) { 999_999 }) do
        Process.stub(:waitpid, nil) do
          ActionCable.server.stub(:broadcast, ->(name, data) { broadcasts << [name, data] }) do
            DataCycleCore::ClassificationMappingJob.new.perform(classification_alias.id, [], [])
          end
        end
      end

      unlock = broadcasts.find { |name, _| name == 'classification_update' }

      assert_equal 'unlock', unlock[1][:type]
      assert_equal classification_alias.id, unlock[1][:id]
    end

    test 'notify_with_lock broadcasts a lock message' do
      broadcasts = []
      job = DataCycleCore::ClassificationMappingJob.new(UUID)

      ActionCable.server.stub(:broadcast, ->(name, data) { broadcasts << [name, data] }) do
        job.send(:notify_with_lock)
      end

      assert_equal [['classification_update', { type: 'lock', id: UUID }]], broadcasts
    end

    test 'exposes reference id, type and priority' do
      job = DataCycleCore::ClassificationMappingJob.new(UUID)

      assert_equal UUID, job.delayed_reference_id
      assert_equal 'ClassificationMappingJob', job.delayed_reference_type
      assert_equal DataCycleCore::ClassificationMappingJob::PRIORITY, job.priority
    end
  end
end
