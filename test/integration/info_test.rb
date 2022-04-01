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
        user: User.find_by(email: 'guest@datacycle.at')&.attributes&.merge(password: 'vdr5pmx@juv9BMJ6ujt')
      }

      assert_redirected_to unauthorized_exception_path
      assert_equal I18n.t('devise.sessions.signed_in', locale: DataCycleCore.ui_locales.first), flash[:notice]
    end
  end
end
