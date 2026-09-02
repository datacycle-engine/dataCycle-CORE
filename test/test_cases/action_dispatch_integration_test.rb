# frozen_string_literal: true

require 'helpers/minitest_hook_helper'
require 'helpers/active_storage_helper'

module DataCycleCore
  module TestCases
    class ActionDispatchIntegrationTest < ActionDispatch::IntegrationTest
      include ActiveJob::TestHelper
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers
      include DataCycleCore::MinitestHookHelper
      include DataCycleCore::ActiveStorageHelper

      attr_reader :current_user

      delegate :create_watch_list, to: 'DataCycleCore::TestPreparations'

      before(:all) do
        @routes = Engine.routes
      end

      private

      def create_content(template_name, data = {}, user = nil, prevent_history: false)
        content = DataCycleCore::TestPreparations
          .create_content(template_name:, data_hash: data, user:, prevent_history:)
        perform_enqueued_jobs
        content
      end
    end
  end
end
