# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V2
      class ContentsSearchTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test '/api/v2/contents/search w/o any results' do
          get api_v2_contents_search_path

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal 0, json_data['data'].length
          assert_equal 0, json_data['meta']['total'].to_i
          assert_equal true, json_data['links'].present?
        end
      end
    end
  end
end
