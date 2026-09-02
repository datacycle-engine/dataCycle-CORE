# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class JobQueueValidationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def validation(*queues)
      DataCycleCore::JobQueueValidation.new(SolidQueue::Configuration.new(workers: queues.map { |q| { queues: q } }), config_file: nil)
    end

    def all_queues
      DataCycleCore.job_queues.keys.map(&:to_s)
    end

    def in_production(&)
      Rails.stub(:env, ActiveSupport::StringInquirer.new('production'), &)
    end

    test 'a queue with no worker of its own is reported' do
      errors = validation(all_queues - ['search_update']).errors

      assert_equal 1, errors.size
      assert_includes errors.first, "'search_update'"
    end

    test 'every job queue served leaves nothing to report' do
      assert_empty validation(all_queues).errors
    end

    test 'the queues left without a worker on purpose are only expected in production' do
      queues = all_queues - DataCycleCore::JobQueueValidation::UNSERVED_LOCALLY.map(&:to_s)

      assert_empty validation(queues).errors
      in_production { assert_equal 1, validation(queues).errors.size }
    end

    test 'a wildcard worker serves every queue' do
      assert_empty validation('*').errors
    end

    test 'a comma separated queue list is read the way SolidQueue reads it' do
      assert_equal ['default', 'mailers'], validation('default, mailers').configured_queues
    end

    test 'a prefix wildcard serves the queues below it' do
      config = validation('importers*')

      assert config.served?(:importers)
      assert config.served?(:importers_short)
      assert_not config.served?(:mailers)
    end

    test 'an external system on a queue that is not an importer queue is reported' do
      external_system = DataCycleCore::ExternalSystem.first
      external_system.update!(default_options: (external_system[:default_options] || {}).merge('queue' => 'importers_extra_short'))

      errors = validation('*').errors

      assert_equal 1, errors.size
      assert_includes errors.first, 'importers_extra_short'
    end

    test 'an external system on a known importer queue is fine' do
      external_system = DataCycleCore::ExternalSystem.first
      external_system.update!(default_options: (external_system[:default_options] || {}).merge('queue' => 'importers_short'))

      assert_empty validation('*').errors
    end

    # dc:validate runs in CI over a checkout that never gets a database, and in a project before its
    # first migration; the queue.yml checks are what it is there for in both cases
    test 'external systems are not reported on when there is no database to read them from' do
      external_system = DataCycleCore::ExternalSystem.first
      external_system.update!(default_options: (external_system[:default_options] || {}).merge('queue' => 'importers_extra_short'))

      DataCycleCore::ExternalSystem.stub(:table_exists?, -> { raise ActiveRecord::NoDatabaseError }) do
        assert_empty validation('*').errors
      end
    end

    test 'a missing queue.yml is reported even though the fallback serves every queue' do
      config = DataCycleCore::JobQueueValidation.new(SolidQueue::Configuration.new(config_file: 'config/no_such_queue.yml'), config_file: 'config/no_such_queue.yml')

      assert config.served?(:importers), 'the SolidQueue fallback claims from every queue'
      assert_equal 1, config.errors.size
      assert_includes config.errors.first, 'config/no_such_queue.yml'
    end
  end
end
