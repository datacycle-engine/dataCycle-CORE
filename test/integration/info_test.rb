# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class InfoTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test 'info path always available' do
      get info_path
      assert_response :success
    end

    test 'redirect guest user to info page' do
      logout
      post user_session_path, params: {
        user: User.find_by(email: 'guest@datacycle.at')&.attributes&.merge(password: 'PdebUfWF9aab2KG6')
      }

      assert_redirected_to info_path
      assert_equal 'Erfolgreich angemeldet.', flash[:notice]
    end
  end
end