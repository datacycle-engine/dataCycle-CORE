# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # The page a stale process answers with once StaleProcess has latched: first through its own
  # route, so the view, the locale key and the Retry-After header are covered without depending
  # on how ExceptionsController got there, then through the /500 the exceptions_app actually
  # routes a 500 to, which is where the verdict decides between the two pages.
  class ServiceUnavailableExceptionTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test 'the page renders with the 503 status and a Retry-After' do
      get service_unavailable_exception_path

      assert_response :service_unavailable
      assert_equal DataCycleCore::StaleProcess::RETRY_AFTER.to_s, response.headers['Retry-After']
      assert_includes response.body, I18n.t('exceptions_page.service_unavailable', locale: DataCycleCore.ui_locales.first)
    end

    test 'an api client gets the status without the html page' do
      get service_unavailable_exception_path, headers: { 'Accept' => 'application/json' }

      assert_response :service_unavailable
      assert_equal ['Service Unavailable'], response.parsed_body['errors']
    end

    test 'a stale process answers the 500 route with the maintenance page' do
      DataCycleCore::StaleProcess.stub(:stale?, true) do
        get internal_server_error_exception_path
      end

      assert_response :service_unavailable
      assert_equal DataCycleCore::StaleProcess::RETRY_AFTER.to_s, response.headers['Retry-After']
      assert_includes response.body, I18n.t('exceptions_page.service_unavailable', locale: DataCycleCore.ui_locales.first)
    end

    test 'a current process keeps the 500 route on the error page' do
      DataCycleCore::StaleProcess.stub(:stale?, false) do
        get internal_server_error_exception_path
      end

      assert_response :internal_server_error
      assert_nil response.headers['Retry-After']
      assert_includes response.body, I18n.t('exceptions_page.internal_server_error', locale: DataCycleCore.ui_locales.first)
    end
  end
end
