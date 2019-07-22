# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class RoutingTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @test_content = DataCycleCore::DummyDataHelper.create_data('tour')
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test '/api/v4/things' do
          count = DataCycleCore::Thing.where(template: false).with_content_type('entity').count

          get api_v4_things_path
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(count, json_data['@graph'].length)
          assert_equal(count, json_data['meta']['total'].to_i)
          assert_equal(true, json_data['links'].present?)
        end

        test '/api/v4/things/:id' do
          get api_v4_thing_path(id: @test_content.id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body
          assert_equal(api_v4_thing_url(id: @test_content.id), json_data['@id'])
        end
      end
    end
  end
end
