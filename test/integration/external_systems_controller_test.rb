# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ExternalSystemsControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    setup do
      sign_in(DataCycleCore::User.find_by(email: 'admin@datacycle.at'))
    end

    test 'index lists importer names' do
      get external_systems_path

      assert_response :success
    end

    test 'render_new_form returns empty html for a blank identifier' do
      get render_new_form_external_systems_path, params: { external_system: { identifier: '' } }

      assert_response :success
      assert_equal '', response.parsed_body['html']
    end

    test 'render_new_form renders the default form template for an unknown identifier' do
      get render_new_form_external_systems_path, params: { external_system: { identifier: 'cov-unknown-identifier' } }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'create with an unknown identifier responds not found' do
      post external_systems_path, params: { external_system: { identifier: 'cov-nonexistent-template' } }

      assert_response :not_found
    end

    test 'authorize is forbidden for a non google business external system' do
      es = DataCycleCore::ExternalSystem.create!(name: 'Cov Authorize', identifier: 'cov-authorize', config: { 'download_config' => {} })

      get authorize_external_system_path(es.id)

      assert_response :forbidden
    end

    test 'callback is forbidden for a non google business external system' do
      es = DataCycleCore::ExternalSystem.create!(name: 'Cov Callback', identifier: 'cov-callback', config: { 'download_config' => {} })

      get callback_external_system_path(es.id)

      assert_response :forbidden
    end
  end
end
