# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class DownloadsControllerCoverageTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        include DataCycleCore::ApiV4Helper

        before(:all) do
          @routes = Engine.routes
          @user = User.find_by(email: 'tester@datacycle.at')
          @endpoint = DataCycleCore::StoredFilter.create!(name: 'download endpoint', user: @user, language: ['de'], api: true)
        end

        setup do
          sign_in(@user)
        end

        test 'endpoint download rejects an unknown serialization format' do
          get api_v4_download_endpoint_path(id: @endpoint.id, serializeFormat: 'not-a-real-format')

          assert_response :bad_request
        end
      end
    end
  end
end
