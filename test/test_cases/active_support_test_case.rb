# frozen_string_literal: true

require 'helpers/minitest_hook_helper'

module DataCycleCore
  module TestCases
    class ActiveSupportTestCase < ActiveSupport::TestCase
      include DataCycleCore::MinitestHookHelper
    end
  end
end
