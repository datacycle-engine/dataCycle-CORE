# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Framework defaults lib/data_cycle_core.rb deviates from, pinned so a `load_defaults` bump
  # cannot flip them back silently.
  class RailsDefaultsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'yjit stays enabled outside production' do
      assert(Rails.application.config.yjit, 'expected config.yjit to be true in the test environment')
      # config.yjit only asks railties to call RubyVM::YJIT.enable, a no-op on a build without it
      assert_predicate(RubyVM::YJIT, :enabled?) if RbConfig::CONFIG['YJIT_SUPPORT'] == 'yes'
    end
  end
end
