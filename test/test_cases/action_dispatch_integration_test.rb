# frozen_string_literal: true

require 'minitest/hooks'

module DataCycleCore
  module TestCases
    class ActionDispatchIntegrationTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers
      include Minitest::Hooks

      around(:all) do |&block|
        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          super(&block)
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end
