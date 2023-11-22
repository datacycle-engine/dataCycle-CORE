# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      class ExternalSystemShowTest < DataCycleCore::V4::Base
        before(:all) do
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { 'name' => 'My_test' })
          @content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { 'name' => 'My_test-2' })
          @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
          @external_key = 'external_key_1'
          @external_key2 = 'external_key_2'
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

        test 'find thing by external_system_id and external_key via /api/v4/external_sources/uuid/things/select' do
          @content.update_columns(external_source_id: @external_system.id, external_key: @external_key)
          @content2.update_columns(external_source_id: @external_system.id, external_key: @external_key2)
          params = {
            external_source_id: @external_system.id,
            external_keys: "#{@external_key},#{@external_key2}"
          }

          get api_v4_things_select_by_external_key_path(params)
          json_data = response.parsed_body
          assert_context(json_data.dig('@context'), 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content2.id].sort, json_data['@graph'].pluck('@id').sort)

          post api_v4_things_select_by_external_key_path(params)
          json_data = response.parsed_body
          assert_context(json_data.dig('@context'), 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content2.id].sort, json_data['@graph'].pluck('@id').sort)
        end
      end
    end
  end
end
