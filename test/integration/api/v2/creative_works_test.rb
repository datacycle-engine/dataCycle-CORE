# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V2
      class CreativeWorkTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          DataCycleCore::Thing.delete_all
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api for article' do
          name = "test_artikel_#{Time.now.getutc.to_i}"
          post things_path, params: {
            thing: {
              datahash: {
                name:
              }
            },
            table: 'things',
            template: 'Artikel',
            locale: 'de'
          }
          assert_equal 'Artikel wurde erfolgreich erstellt.', flash[:success]

          content = DataCycleCore::Thing.where_translated_value(name:).first

          get api_v2_thing_path(id: content)

          assert_response :success
          assert_equal response.content_type, 'application/json; charset=utf-8'
          json_data = JSON.parse response.body
          assert_equal name, json_data['headline']
        end
      end
    end
  end
end
