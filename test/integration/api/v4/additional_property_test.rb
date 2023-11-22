# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class AdditionalPropertyTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes
          @content = DataCycleCore::DummyDataHelper.create_data('additional_property')
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'json of stored article exists' do
          get api_v4_thing_path(id: @content, include: 'embeddedData')

          assert_response(:success)
          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          assert(json_data['@context'].present?)
          assert_equal('de', json_data.dig('@context', 1, '@language'))

          json_data = json_data.dig('@graph').first
          assert_equal(@content.id, json_data['@id'])
          assert_equal(@content.api_type, json_data['@type'])
          assert_equal(@content.name, json_data['name'])

          assert_equal(1, json_data['additionalProperty'].count)
          assert_equal('PropertyValue', json_data['additionalProperty'][0]['@type'])
          assert_equal('text', json_data['additionalProperty'][0]['identifier'])
          assert_equal('text', json_data['additionalProperty'][0]['name'])
          assert_equal(@content.text, json_data['additionalProperty'][0]['value'])

          assert_equal(@content.embedded_data.count, json_data['embeddedData'].count)
          assert_equal(1, json_data['embeddedData'].count)
          embedded_data = @content.embedded_data.first
          json_ed = json_data['embeddedData'].first
          assert_equal(embedded_data.api_type, json_ed['@type'])
          assert_equal(embedded_data.name, json_ed['name'])

          assert_equal(2, json_ed['additionalProperty'].count)
          assert_equal(embedded_data.add1, json_ed['additionalProperty'].detect { |item| item.dig('identifier') == 'add1' }.dig('value'))
          assert_equal(embedded_data.add1, json_ed['additionalProperty'].detect { |item| item.dig('name') == 'add1' }.dig('value'))
          assert_equal(embedded_data.add2, json_ed['additionalProperty'].detect { |item| item.dig('identifier') == 'add2' }.dig('value'))
          assert_equal(embedded_data.add2, json_ed['additionalProperty'].detect { |item| item.dig('name') == 'add2' }.dig('value'))
          assert_equal('PropertyValue', json_ed['additionalProperty'][0]['@type'])
          assert_equal('PropertyValue', json_ed['additionalProperty'][1]['@type'])
        end
      end
    end
  end
end
