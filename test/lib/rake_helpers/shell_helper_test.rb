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
  end
end
