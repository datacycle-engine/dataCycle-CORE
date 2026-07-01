# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the RunRakeTask import strategy (no Mongo). The actual rake
      # invocation (happy path) is left out to avoid touching the global Rake app.
      class RunRakeTaskCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::RunRakeTask
        end

        def logging_double
          Class.new {
            def phase_started(*) = nil
            def phase_finished(*) = nil
            def close = nil
          }.new
        end

        def utility_object
          logger = logging_double
          Class.new {
            define_method(:init_logging) { |_type| logger }
            define_method(:step_label) { |_options| 'rake step' }
          }.new
        end

        test 'process_content raises when no rake task is configured' do
          assert_raises(RuntimeError) { subject.process_content(nil, {}) }
        end

        test 'source_type? is false' do
          assert_not(subject.source_type?)
        end

        test 'import_data runs the processor through logging_without_mongo' do
          # process_content raises (no rake task); logging_without_mongo propagates it
          assert_raises(RuntimeError) do
            subject.import_data(utility_object:, options: {})
          end
        end
      end
    end
  end
end
