# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class RakeTaskServiceTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # a throwaway Rake app keeps the definitions below out of the registry the suite runs in
    def with_rake_app
      previous = Rake.application
      Rake.application = Rake::Application.new
      yield
    ensure
      Rake.application = previous
    end

    test 'load_tasks loads the rake tasks once per process' do
      loads = 0

      with_rake_app do
        load_tasks = lambda {
          loads += 1
          Rake::Task.define_task(:environment)
        }

        Rails.application.stub(:load_tasks, load_tasks) do
          DataCycleCore::RakeTaskService.load_tasks
          DataCycleCore::RakeTaskService.load_tasks
        end
      end

      assert_equal 1, loads
    end

    test 'invoke reenables the task, so a failed run does not poison the next one' do
      runs = 0

      with_rake_app do
        Rake::Task.define_task('dc_test:flaky') do
          runs += 1
          raise 'boom' if runs == 1
        end

        Rails.application.stub(:load_tasks, nil) do
          assert_raises(RuntimeError) { DataCycleCore::RakeTaskService.invoke('dc_test:flaky') }
          DataCycleCore::RakeTaskService.invoke('dc_test:flaky')
        end
      end

      assert_equal 2, runs
    end

    test 'invoke passes the arguments on to the task' do
      received = nil

      with_rake_app do
        Rake::Task.define_task('dc_test:with_args', [:one, :two]) do |_, args|
          received = [args.one, args.two]
        end

        Rails.application.stub(:load_tasks, nil) do
          DataCycleCore::RakeTaskService.invoke('dc_test:with_args', ['a', 'b'])
        end
      end

      assert_equal ['a', 'b'], received
    end
  end
end
