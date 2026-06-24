# frozen_string_literal: true

require 'helpers/minitest_hook_helper'
require 'helpers/active_storage_helper'

module DataCycleCore
  module TestCases
    class ActionDispatchIntegrationTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers
      include DataCycleCore::MinitestHookHelper
      include DataCycleCore::ActiveStorageHelper

      attr_reader :current_user

      before(:all) do
        @routes = Engine.routes
      end

      private

      def create_content(template_name, data = {}, user = nil)
        DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data, user:)
      end
    end
  end
end
