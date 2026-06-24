# frozen_string_literal: true

require 'test_helper'
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

      def cron(rule, &block)
        @scheduled << [:cron, rule]
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
      assert_equal 4, scheduler.instance_variable_get(:@paths).size
      assert_equal ENV['RAILS_ENV'], scheduler.instance_variable_get(:@rails_env)
    end

    test 'run_task ignores blank tasks and runs rails for present ones' do
      scheduler = build_scheduler

      assert_nil scheduler.run_task(nil)
      assert_nil scheduler.run_task('   ')

      commands = []
      scheduler.stub(:system, lambda { |cmd|
        commands << cmd
        true
      }) do
        scheduler.run_task('db:migrate')
      end

      assert_equal ['rails db:migrate'], commands
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
        scheduler.stub(:system, lambda { |cmd|
          commands << cmd
          true
        }) do
          scheduler.run
        end

        assert_includes fake.scheduled, [:every, '1h']
        assert_includes fake.scheduled, [:cron, nil]
        assert_includes fake.scheduled, [:cron, '0 0 * * *']
        assert_equal ['rails task_one', 'rails task_two', 'rails task_three'], commands
      end
    end
  end
end
