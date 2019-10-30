# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class FieldsIncludeTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        setup do
          @routes = Engine.routes
          @content_overlay = DataCycleCore::DummyDataHelper.create_data('event')
          @content_overlay.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_period: { start_date: 8.days.ago, end_date: 8.days.from_now } })
          image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
          image_data_hash['name'] = 'Another Image'
          @overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

          place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi')
          place_data_hash['name'] = 'Another Place'
          @overlay_place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: place_data_hash)

          @data_hash = {
            'overlay' => [
              {
                'name' => 'overlay_name',
                'description' => '<p>overlay_description</p>',
                'image' => [@overlay_image.id],
                'content_location' => [@overlay_place.id],
                'url' => 'https://overlay.url.com',
                'event_period' => {
                  'start_date' => '2019-11-10T00:00:00.000+01:00',
                  'end_date' => '2019-11-20T00:00:00.000+01:00'
                }
              }
            ]
          }
          @content_overlay.set_data_hash(data_hash: @data_hash, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
          @content_overlay.reload
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        def load_api_data(fields, includes)
          get api_v4_thing_path(id: @content_overlay, fields: fields&.join(','), include: includes&.join(','))
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          JSON.parse(response.body)
        end

        test 'testing EventOverlay with fields and include parameter (only fields in main objext --> no incuded data)' do
          fields = ['name']
          includes = ['image', 'location', 'subEvent']
          json_data = load_api_data(fields, includes)

          assert_equal(fields, json_data.keys)
        end

        test 'testing EventOverlay with fields and include parameter (one included data)' do
          fields = ['image.name']
          includes = ['image', 'location', 'subEvent']
          json_data = load_api_data(fields, includes)

          assert_equal(['image'], json_data.keys)
          assert_equal(['name'], json_data.dig('image', 0).keys)
          assert_equal(@overlay_image.name, json_data.dig('image', 0, 'name'))
        end

        test 'testing EventOverlay with fields and include parameter (field not in includes --> no data)' do
          fields = ['image.name', 'name']
          includes = ['location', 'subEvent']
          json_data = load_api_data(fields, includes)

          assert_equal(['name'], json_data.keys)
        end
      end
    end
  end
end
