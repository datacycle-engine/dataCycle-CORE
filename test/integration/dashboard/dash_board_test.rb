# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Dashboard
    class DashBoardTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers

      setup do
        @routes = Engine.routes
        sign_in(User.find_by(email: 'admin@datacycle.at'))
      end

      test 'admin dashboard' do
        get admin_path
        assert_response :success
      end
    end
  end
end
