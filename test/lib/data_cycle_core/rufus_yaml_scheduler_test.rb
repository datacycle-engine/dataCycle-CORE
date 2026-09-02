# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'data_cycle_core/rufus_yaml_scheduler'

module DataCycleCore
  class RufusYamlSchedulerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # Records every job scheduled on it and runs the block immediately so the
    # task bodies are exercised. join is a no-op so run does not block forever.
    class FakeScheduler
      attr_reader :scheduled

      def initialize
        @scheduled = []
      end

      def cron(rule, opts = {}, &block)
        @scheduled << [:cron, rule, opts]
        block&.call
      end

      def method_missing(name, *args, &block)
        @scheduled << [name, *args]
        block&.call
      end

      def respond_to_missing?(*)
        true
      end

      def join
      end
    end

    def build_scheduler
      scheduler = DataCycleCore::RufusYamlScheduler.new
      scheduler.instance_variable_get(:@scheduler).shutdown
      scheduler
    end

    test 'initialize sets up the scheduler, environment and config paths' do
      scheduler = build_scheduler

      assert_kind_of Array, scheduler.instance_variable_get(:@paths)
      assert_equal 6, scheduler.instance_variable_get(:@paths).size
      assert_equal ENV['RAILS_ENV'], scheduler.instance_variable_get(:@rails_env)
    end

    # so a schedule that belongs to a schema or connector can ship with that gem instead of being
    # copied into every project's schedule.yml (#37010)
    test 'initialize reads schedules from vendored datacycle gems, environment ones included' do
      Dir.mktmpdir do |dir|
        gem_config = File.join(dir, 'vendor', 'gems', 'datacycle-schema-test', 'config', 'configurations')
        FileUtils.mkdir_p(File.join(gem_config, ENV.fetch('RAILS_ENV', 'test')))
        shared = File.join(gem_config, 'schedule.yml')
        env_only = File.join(gem_config, ENV.fetch('RAILS_ENV', 'test'), 'schedule.yml')
        [shared, env_only].each { |file| File.write(file, YAML.dump([{ '0 4 * * *' => ['dc:clean_up:archive_orphans[cleanup,POI,3]'] }])) }

        paths = Dir.stub(:pwd, dir) { build_scheduler.instance_variable_get(:@paths) }.flatten

        assert_includes paths, shared
        assert_includes paths, env_only
      end
    end

    test 'run_task ignores blank tasks and runs rails for present ones' do
      scheduler = build_scheduler

      assert_nil scheduler.run_task(nil)
      assert_nil scheduler.run_task('   ')

      commands = []
      scheduler.stub(:system, lambda { |*args|
        commands << args
        true
      }) do
        scheduler.run_task('db:migrate')
      end

      assert_equal [['rails', 'db:migrate']], commands
    end

    test 'run_task passes rake task arguments as a single unquoted argv entry' do
      scheduler = build_scheduler

      commands = []
      scheduler.stub(:system, lambda { |*args|
        commands << args
        true
      }) do
        scheduler.run_task("dc:import:append_job['canto_dam']")
        scheduler.run_task("dc:import:append_job['canto_dam',full]")
      end

      assert_equal [
        ['rails', 'dc:import:append_job[canto_dam]'],
        ['rails', 'dc:import:append_job[canto_dam,full]']
      ], commands
    end

    test 'run schedules tasks from both config formats and runs them' do
      Dir.mktmpdir do |dir|
        typed = File.join(dir, 'typed.yml')
        cron = File.join(dir, 'cron.yml')
        invalid = File.join(dir, 'invalid.yml')

        File.write(typed, YAML.dump([
                                      { 'type' => 'every', 'time' => '1h', 'task' => ['task_one'] },
                                      { 'task' => 'task_two' }
                                    ]))
        File.write(cron, YAML.dump([{ '0 0 * * *' => ['task_three'] }]))
        File.write(invalid, YAML.dump({ 'not' => 'an array' }))

        scheduler = build_scheduler
        fake = FakeScheduler.new
        scheduler.instance_variable_set(:@scheduler, fake)
        scheduler.instance_variable_set(:@paths, [[typed], [cron], [invalid], []])

        commands = []
        scheduler.stub(:system, lambda { |*args|
          commands << args
          true
        }) do
          scheduler.run
        end

        assert_includes fake.scheduled, [:every, '1h', { overlap: false }]
        assert_includes fake.scheduled, [:cron, nil, { overlap: false }]
        assert_includes fake.scheduled, [:cron, '0 0 * * *', { overlap: false }]
        assert_equal [['rails', 'task_one'], ['rails', 'task_two'], ['rails', 'task_three']], commands
      end
    end
  end
end
