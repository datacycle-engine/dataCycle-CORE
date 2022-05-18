# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class DefaultValueValidationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'DefaultValueBildTest' })
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      test 'validation works with translated contents and empty default_value for name' do
        post validate_thing_path(@content), xhr: true, params: {
          locale: 'en',
          thing: {
            datahash: {
              content_location: []
            }
          }
        }

        assert_response :success
        assert_equal 'application/json; charset=utf-8', response.content_type
        json_data = JSON.parse response.body
        assert json_data['valid']
        assert_empty json_data['errors']
        assert_empty json_data['warnings']
      end
    end
  end
end
