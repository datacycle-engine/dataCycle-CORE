# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V2
      class RoutingTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api for article' do
          name = "test_artikel_#{Time.now.getutc.to_i}"
          post things_path, params: {
            thing: {
              datahash: {
                name: name
              }
            },
            table: 'things',
            template: 'Artikel',
            locale: 'de'
          }
          assert_equal 'Artikel wurde erfolgreich erstellt.', flash[:notice]

          content = DataCycleCore::Thing.find_by(name: name)

          get api_v2_thing_path(content)

          assert_response :success
          assert_equal response.content_type, 'application/json'
          json_data = JSON.parse response.body
          assert_equal name, json_data['headline']
        end
      end
    end
  end
end
