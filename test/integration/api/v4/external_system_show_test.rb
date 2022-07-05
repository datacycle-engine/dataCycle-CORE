# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class ExternalSystemShowTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { 'name' => 'My_test' })
          @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
          @external_key = 'external_key_1'
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'find thing by external_system_id and external_key' do
          @content.update_columns(external_source_id: @external_system.id, external_key: @external_key)

          get api_v4_external_sources_path(external_source_id: @external_system.id, external_key: @external_key)

          assert_redirected_to api_v4_thing_path(id: @content.id)
        end

        test 'find thing by external_system_id and external_key in external_system_syncs' do
          @content.add_external_system_data(@external_system, nil, nil, 'import', @external_key)

          get api_v4_external_sources_path(external_source_id: @external_system.id, external_key: @external_key)

          assert_redirected_to api_v4_thing_path(id: @content.id)
        end

        test 'find thing by external_system identifier and external_key' do
          @content.update_columns(external_source_id: @external_system.id, external_key: @external_key)

          get api_v4_external_sources_path(external_source_id: @external_system.identifier, external_key: @external_key)

          assert_redirected_to api_v4_thing_path(id: @content.id)
        end

        test 'find thing by external_system identifier and external_key in external_system_syncs' do
          @content.add_external_system_data(@external_system, nil, nil, 'import', @external_key)

          get api_v4_external_sources_path(external_source_id: @external_system.identifier, external_key: @external_key)

          assert_redirected_to api_v4_thing_path(id: @content.id)
        end

        test 'response not_found' do
          get api_v4_external_sources_path(external_source_id: @external_system.id, external_key: @external_key)

          assert_response :not_found
        end
      end
    end
  end
end
