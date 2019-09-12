# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class ClassificationTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @content = DataCycleCore::DummyDataHelper.create_data('poi')
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'concepts at /api/v4/things/:id serializes with only minimal header' do
          get api_v4_thing_path(id: @content.id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          # full header of main item
          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content)
          assert_equal(header, data)
          assert_compact_classification_header(json_data.dig('concepts'))
        end
      end
    end
  end
end
