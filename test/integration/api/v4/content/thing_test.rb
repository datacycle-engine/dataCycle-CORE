# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'v4/helpers/dummy_data_helper'
require 'v4/helpers/api_helper'

module DataCycleCore
  module Api
    module V4
      class Thing < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::V4::ApiHelper
        include DataCycleCore::V4::DummyDataHelper

        setup do
          @routes = Engine.routes
          @event = DataCycleCore::V4::DummyDataHelper.create_data('event')
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api_v4_thing_path validate full event' do
          assert_full_thing_datahash(@event)
          params = {
            id: @event.id
          }
          post api_v4_thing_path(params)
          json_data = JSON.parse response.body
          assert_equal(@event.id, json_data.dig('@id'))
        end
      end
    end
  end
end
