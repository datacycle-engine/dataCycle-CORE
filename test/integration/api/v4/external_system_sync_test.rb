# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class ExternalSystemSyncTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          sign_in(User.find_by(email: 'tester@datacycle.at'))

          @data_set = create_data({ 'name' => 'My_test' })

          external_thing_data = { 'key_1' => 'value_1' }
          @external_system = DataCycleCore::ExternalSystem.find_by(name: 'Exozet')
          @data_set.add_external_system_data(@external_system, external_thing_data)
        end

        def item_body(id, system_name, external_key)
          {
            '@id' => id,
            '@type' => 'who cares',
            'name' => 'who cares',
            'inLanguage' => 'who cares',
            'identifier' => [{
              '@type' => 'who cares',
              'propertyID' => system_name,
              'value' => external_key
            }],
            'url' => 'who cares'
          }
        end

        def create_data(data)
          data_set = DataCycleCore::TestPreparations.data_set_object('Artikel')
          data_set.save
          data_set.set_data_hash(data_hash: data, update_search_all: false)
          data_set.save
          data_set
        end

        test 'update external_key in external system sync for a thing' do
          new_external_key = 'new_cms_id'
          request_body = { '@graph' => item_body(@data_set.id, @external_system.name, new_external_key) }
          patch api_v4_external_sources_update_path(external_source_id: @external_system.id), params: request_body, as: :json
          assert_response :success

          assert_equal(new_external_key, @data_set.external_system_data(@external_system).dig('external_key'))
          data = JSON.parse(response.body)
          assert_equal([{ 'update' => @data_set.id }], data)
        end

        test 'update external_key for two things' do
          data_set2 = create_data({ 'name' => 'My_test2' })
          new_external_key1 = 'new_cms_id1'
          new_external_key2 = 'new_cms_id2'
          request_body = {
            '@graph' => [
              item_body(@data_set.id, @external_system.name, new_external_key1),
              item_body(data_set2.id, @external_system.name, new_external_key2)
            ]
          }
          patch api_v4_external_sources_update_path(external_source_id: @external_system.id), params: request_body, as: :json
          assert_response :success

          assert_equal(new_external_key1, @data_set.external_system_data(@external_system).dig('external_key'))
          assert_equal(new_external_key2, data_set2.external_system_data(@external_system).dig('external_key'))
          data = JSON.parse(response.body)
          assert_equal([{ 'update' => @data_set.id }, { 'update' => data_set2.id }], data)
        end

        test 'update external_key in external system sync for a thing that does not exist' do
          new_external_key = 'new_cms_id'
          thing_id = SecureRandom.uuid
          request_body = { '@graph' => item_body(thing_id, @external_system.name, new_external_key) }

          patch api_v4_external_sources_update_path(external_source_id: @external_system.id), params: request_body, as: :json
          assert_response :bad_request

          assert_nil(@data_set.external_system_data(@external_system).dig('external_key'))
          data = JSON.parse(response.body)
          assert_equal(1, data.first['error'].size)
        end

        test 'delete external_key in external system sync for a thing' do
          new_external_key = 'new_cms_id'
          @data_set.add_external_system_data(@external_system, { 'external_key' => new_external_key })
          assert_equal(new_external_key, @data_set.external_system_data(@external_system).dig('external_key'))
          request_body = { '@graph' => item_body(@data_set.id, @external_system.name, new_external_key) }

          delete api_v4_external_sources_delete_path(external_source_id: @external_system.id), params: request_body, as: :json
          assert_response :success

          assert_nil(@data_set.external_system_data(@external_system).dig('external_key'))
          data = JSON.parse(response.body)
          assert_equal([{ 'delete' => @data_set.id }], data)
        end

        test 'delete external_key for two things' do
          data_set2 = create_data({ 'name' => 'My_test2' })
          new_external_key1 = 'new_cms_id1'
          new_external_key2 = 'new_cms_id2'
          @data_set.add_external_system_data(@external_system, { 'external_key' => new_external_key1 })
          data_set2.add_external_system_data(@external_system, { 'external_key' => new_external_key2 })
          assert_equal(new_external_key1, @data_set.external_system_data(@external_system).dig('external_key'))
          assert_equal(new_external_key2, data_set2.external_system_data(@external_system).dig('external_key'))

          request_body = {
            '@graph' => [
              item_body(@data_set.id, @external_system.name, new_external_key1),
              item_body(data_set2.id, @external_system.name, new_external_key2)
            ]
          }
          delete api_v4_external_sources_delete_path(external_source_id: @external_system.id), params: request_body, as: :json
          assert_response :success

          assert_nil(@data_set.external_system_data(@external_system).dig('external_key'))
          assert_nil(data_set2.external_system_data(@external_system).dig('external_key'))
          data = JSON.parse(response.body)
          assert_equal([{ 'delete' => @data_set.id }, { 'delete' => data_set2.id }], data)
        end

        test 'delete external_key in external system sync for a thing that does not exist' do
          new_external_key = 'new_cms_id'
          thing_id = SecureRandom.uuid
          request_body = { '@graph' => item_body(thing_id, @external_system.name, new_external_key) }

          delete api_v4_external_sources_delete_path(external_source_id: @external_system.id), params: request_body, as: :json
          assert_response :bad_request

          assert_nil(@data_set.external_system_data(@external_system).dig('external_key'))
          data = JSON.parse(response.body)
          assert_equal(1, data.first['error'].size)
        end

        test 'sending request to a system that does not exist' do
          new_external_key = 'new_cms_id'
          thing_id = SecureRandom.uuid
          request_body = { '@graph' => item_body(thing_id, @external_system.name, new_external_key) }

          delete api_v4_external_sources_delete_path(external_source_id: SecureRandom.uuid), params: request_body, as: :json
          assert_response :not_found

          patch api_v4_external_sources_update_path(external_source_id: SecureRandom.uuid), params: request_body, as: :json
          assert_response :not_found
        end
      end
    end
  end
end
