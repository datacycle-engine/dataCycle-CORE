# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module DataCycleCore
  class JobQueueValidationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # The shape of config/queue.yml.template: a threaded worker in the anchor block that development
    # and test inherit, and a deployed section that overrides it, under every environment name
    # test/dummy ships a config/environments file for.
    QUEUE_YAML = <<~YAML
      default: &default
        dispatchers:
          - polling_interval: 1
        workers:
          - queues: "*"
            threads: 3
            processes: 1

      development:
        <<: *default

      test:
        <<: *default

      staging: &production
        <<: *default
        workers:
          - queues: [default, importers, importers_short]
            threads: %<threads>s
            processes: 2

      production: *production
    YAML

    # SolidQueue reads a file that names no environment as the configuration of whichever environment
    # loads it, deployed ones included (+Configuration#config_from+ falls back to the whole
    # document), so the check has to read it as the one section it is.
    FLAT_QUEUE_YAML = <<~YAML
      dispatchers:
        - polling_interval: 1
      workers:
        - queues: "*"
          threads: 3
    YAML

    # QUEUE_YAML with the anchor block under a name of a project's own choosing and nothing else
    # about the file touched, so what the two differ in is the one thing the test is about.
    RENAMED_ANCHOR_QUEUE_YAML = format(QUEUE_YAML, threads: 1)
      .gsub('default: &default', 'base: &base')
      .gsub('<<: *default', '<<: *base')

    # Only the sections a deployment never loads, which is why SolidQueue answers it with
    # WORKER_DEFAULTS: one worker, every queue, three threads.
    LOCAL_ONLY_QUEUE_YAML = <<~YAML
      default: &default
        dispatchers:
          - polling_interval: 1
        workers:
          - queues: "*"
            threads: 3

      development:
        <<: *default

      test:
        <<: *default
    YAML

    # threads: 1 so these fixtures exercise only the queue-coverage checks; the thread count is what
    # the forking-queue tests at the bottom vary on purpose.
    def validation(*queues, threads: 1)
      DataCycleCore::JobQueueValidation.new(SolidQueue::Configuration.new(workers: queues.map { |q| { queues: q, threads: } }), config_file: nil)
    end

    def validation_for(workers)
      DataCycleCore::JobQueueValidation.new(SolidQueue::Configuration.new(workers:), config_file: nil)
    end

    def all_queues
      DataCycleCore.job_queues.map(&:to_s)
    end

    # @return [Pathname] the queue.yml every project gets from dc:upgrade:copy_templates[global]
    def template_queue_yml
      DataCycleCore::Engine.root.join('lib/templates/global/config/queue.yml.template')
    end

    def in_production(&)
      Rails.stub(:env, ActiveSupport::StringInquirer.new('production'), &)
    end

    # Validates a real file, which is where the deployed sections live; SolidQueue reads its test
    # section for the other checks, exactly as it does in CI.
    # @param yaml [String]
    # @yield [DataCycleCore::JobQueueValidation]
    def validation_of_queue_file(yaml)
      Dir.mktmpdir do |dir|
        path = Pathname.new(dir).join('queue.yml')
        path.write(yaml)

        yield DataCycleCore::JobQueueValidation.new(SolidQueue::Configuration.new(config_file: path), config_file: path)
      end
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

    # A wildcard worker serves every queue, so the only error left to count is the forking one, which
    # has to be found without any forking queue being named in the config.
    test 'a multithreaded worker claiming a forking queue is reported' do
      errors = validation_for([{ queues: '*', threads: 3 }]).errors

      assert_equal 1, errors.size
      assert_includes errors.first, 'runs 3 threads'
      DataCycleCore::JobQueueValidation::FORKING_QUEUES.each { |queue| assert_includes errors.first, queue.to_s }
    end

    test 'one job per process leaves nothing to report' do
      assert_empty validation_for([{ queues: '*', threads: 1 }]).errors
    end

    # The shape staging and production use: threads for the queues that do not fork, processes for
    # the ones that do.
    test 'a worker claiming no forking queue may keep its threads' do
      workers = [
        { queues: 'cache_invalidation,content_maintenance,search_update,mailers,webhooks', threads: 3 },
        { queues: 'default,importers,importers_short', threads: 1 }
      ]

      assert_empty validation_for(workers).errors
    end

    # Runs under RAILS_ENV=test, as CI does, where the workers in hand are the shared threaded one
    # the anchor block keeps on purpose; see JobQueueValidation#multithreaded_forking_queues.
    test 'a threaded forking worker in a deployed section is reported whatever environment validates' do
      validation_of_queue_file(format(QUEUE_YAML, threads: 3)) do |validation|
        errors = validation.errors.grep(/runs 3 threads/)

        assert_equal 1, errors.size, 'one message for the two sections and two processes it spans'
        assert_includes errors.first, 'default, importers, importers_short'
      end
    end

    test 'the local sections keep their shared threaded worker' do
      validation_of_queue_file(format(QUEUE_YAML, threads: 1)) { |validation| assert_empty validation.errors }
    end

    # Regression: reading only the sections a deployment names left a file with no environment at all
    # unchecked, since its `workers:` is an Array where a section is a Hash, so the check came back
    # empty on a config SolidQueue runs as it stands.
    test 'a queue.yml that names no environment is checked as the one section it is' do
      validation_of_queue_file(FLAT_QUEUE_YAML) do |validation|
        assert_equal 1, validation.errors.grep(/runs 3 threads/).size
      end
    end

    # Regression: the deployed sections were named by excluding `default`, `development` and `test`,
    # so an anchor block under any other name was read as a section of its own and reported for its
    # shared worker, on a file whose every deployed worker runs one job at a time.
    test 'an anchor block under a name of its own is not a deployed section' do
      validation_of_queue_file(RENAMED_ANCHOR_QUEUE_YAML) { |validation| assert_empty validation.errors }
    end

    # Regression: a file that leaves the deployed environments to SolidQueue's fallback gave the
    # forking check nothing to read and passed, while what it runs is the very worker that check is
    # about. The local sections cover every queue, so no other check reports it either.
    test 'a queue.yml that leaves the deployed environments to the SolidQueue fallback is reported' do
      validation_of_queue_file(LOCAL_ONLY_QUEUE_YAML) do |validation|
        assert validation.served?(:importers), 'the test section claims from every queue'
        assert_equal 1, validation.errors.size
        assert_includes validation.errors.first, 'has no section for production'
        assert_includes validation.errors.first, 'falls back to one worker for all queues'
      end
    end

    # Regression: an environment absent from the file contributed no section rather than the fallback
    # it actually runs, and one deployed section that was there silenced the check for the rest.
    test 'a deployed environment the file names no section for is reported' do
      validation_of_queue_file(format(QUEUE_YAML, threads: 1).sub("\nproduction: *production\n", '')) do |validation|
        assert_equal 1, validation.errors.size
        assert_includes validation.errors.first, 'has no section for production'
        assert_includes validation.errors.first, 'falls back to one worker for all queues'
        # end_with?, because a message ending in dc:upgrade:copy_templates[global] would satisfy an
        # assert_includes on the same string while naming a task that resolves no missing section.
        assert validation.errors.first.end_with?('run rails dc:upgrade')
      end
    end

    test 'a deployed section with nothing under it is that same fallback' do
      validation_of_queue_file("#{LOCAL_ONLY_QUEUE_YAML}\nproduction:\n") do |validation|
        assert_equal 1, validation.errors.size
        assert_includes validation.errors.first, 'has no section for production'
      end
    end

    # A fiber worker carries no threads attribute at all, so reading that alone counted three fibers
    # in one process as one job at a time, on the queues whose jobs fork.
    test 'a fiber worker on a forking queue is reported for its fibers' do
      workers = [{ queues: 'importers', fibers: 3 }]
      error = DataCycleCore::JobQueueValidation.new(SolidQueue::Configuration.new(workers:, only_work: true), config_file: nil)
        .send(:multithreaded_forking_queues)

      assert_equal 1, error.size
      assert_includes error.first, 'runs 3 fibers'
      assert_includes error.first, 'give it fibers: 1'
    end

    # The header of config/queue.yml.template states the one-job-per-process invariant; this is what
    # holds the file to it, and what a project's own copy is measured against after dc:upgrade.
    test 'the shipped queue.yml template validates clean' do
      validation_of_queue_file(template_queue_yml.read) { |validation| assert_empty validation.errors }
    end

    # test/dummy needs a queue.yml of its own for SolidQueue to boot the suite, and the one thing it
    # has to be is the file projects get: a header or a worker changed in one copy alone would leave
    # the suite validating something no project runs.
    test 'the dummy app runs the template it ships' do
      assert_equal template_queue_yml.read, Rails.root.join('config', 'queue.yml').read
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
