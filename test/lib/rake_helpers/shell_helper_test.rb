# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/shell_helper'

module DataCycleCore
  class ShellHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'zsh? reflects the current SHELL environment variable' do
      original = ENV.fetch('SHELL', nil)

      ENV['SHELL'] = '/bin/zsh'

      assert_predicate ShellHelper, :zsh?

      ENV['SHELL'] = '/bin/bash'

      assert_not ShellHelper.zsh?

      ENV.delete('SHELL')

      assert_not ShellHelper.zsh?
    ensure
      original.nil? ? ENV.delete('SHELL') : ENV['SHELL'] = original
    end

    test 'error prints the message and exits' do
      out, = capture_io do
        error = assert_raises(SystemExit) { ShellHelper.error('boom') }
        assert_not error.success?
      end

      assert_includes out, 'boom'
    end

    test 'prompt prints and reads a stripped line from stdin' do
      result = nil

      capture_io do
        $stdin.stub(:gets, "  answer  \n") do
          result = ShellHelper.prompt('question: ')
        end
      end

      assert_equal 'answer', result
    end

    test 'progress_bar prints a full bar once the index reaches the total' do
      out, = capture_io { ShellHelper.progress_bar(10, 10) }

      assert_includes out, '100%'
    end

    test 'progress_bar prints the current fraction on interval ticks' do
      out, = capture_io { ShellHelper.progress_bar(100, 50, 1) }

      assert_includes out, '50%'
    end

    test 'progress_bar skips non interval indices' do
      out, = capture_io { ShellHelper.progress_bar(100, 3, 5) }

      assert_equal '', out
    end

    test 'progress_bar computes a default interval' do
      out, = capture_io { ShellHelper.progress_bar(100, 0) }

      assert_includes out, '0%'
    end
  end
end
