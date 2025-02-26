# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class PermissionsOverviewTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'admin@datacycle.at'))
    end

    test '/permissions provides list of all permissions' do
      get '/permissions'

      assert_response :success

      assert_select 'ul.permission-overview > li:not([data-segment="users_by_user_group_permission"])', {
        count: DataCycleCore::Role.distinct.pluck(:name).size
      }
    end
  end
end
