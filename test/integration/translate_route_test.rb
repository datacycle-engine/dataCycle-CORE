# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  class TranslateRouteTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @routes = Engine.routes
      @current_user = User.find_by(email: 'tester@datacycle.at')
    end

    setup do
      sign_in(@current_user)
    end

    test '/i18n/translate returns translated string' do
      get i18n_translate_path, xhr: true, params: {
        path: 'hello'
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse(response.body)

      assert_equal I18n.translate('hello', locale: @current_user.ui_locale), json_data['text']
    end

    test '/i18n/translate returns correct errors' do
      get i18n_translate_path, xhr: true

      assert_response :bad_request
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse(response.body)
      assert_equal 'PATH_MISSING', json_data['error']

      get i18n_translate_path, xhr: true, params: {
        path: 'not.existing.path'
      }, headers: {
        referer: root_path
      }
      assert_response :not_found
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse(response.body)
      assert_equal 'TRANSLATION_MISSING', json_data['error']
    end

    test '/i18n/translate returns translated string with different locale' do
      @current_user.update(ui_locale: :en)

      assert_equal 'en', @current_user.ui_locale

      get i18n_translate_path, xhr: true, params: {
        path: 'hello'
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse(response.body)

      assert_equal I18n.translate('hello', locale: @current_user.ui_locale), json_data['text']
    end
  end
end
