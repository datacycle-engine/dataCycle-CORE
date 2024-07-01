# frozen_string_literal: true

require 'helpers/minitest_hook_helper'
require 'helpers/active_storage_helper'

module DataCycleCore
  module TestCases
    class ActiveSupportTestCase < ActiveSupport::TestCase
      include DataCycleCore::MinitestHookHelper
      include DataCycleCore::ActiveStorageHelper

      private

      def create_content(template_name, data = {})
        DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data)
      end
    end
  end
end
