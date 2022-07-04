# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V2
      class ExternalSystemSyncTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes
          @data_set = create_data({ 'name' => 'My_test' })
          @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
          @data_set.add_external_system_data(@external_system, external_system_data, nil, 'export', 'remote_system_id', false)
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        def create_data(data)
          DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: data)
        end

        def external_system_data
          { 'key_1' => 'value_1' }
        end

        test 'test external_data helper functions' do
          assert_equal(external_system_data, @data_set.external_system_data(@external_system, 'export', nil, false))
          assert_nil(@data_set.external_system_data(@external_system, 'export', nil, true))
        end
      end
    end
  end
end
