# frozen_string_literal: true

require 'helpers/minitest_hook_helper'

module DataCycleCore
  module TestCases
    class ActionDispatchIntegrationTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers
      include DataCycleCore::MinitestHookHelper

      before(:all) do
        @routes = Engine.routes
      end
    end
  end
end
