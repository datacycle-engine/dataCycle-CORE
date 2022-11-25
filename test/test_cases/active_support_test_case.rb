# frozen_string_literal: true

require 'helpers/minitest_hook_helper'
require 'helpers/active_storage_helper'

module DataCycleCore
  module TestCases
    class ActiveSupportTestCase < ActiveSupport::TestCase
      include DataCycleCore::MinitestHookHelper
      include DataCycleCore::ActiveStorageHelper
    end
  end
end
