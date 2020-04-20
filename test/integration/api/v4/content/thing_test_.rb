# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'v4/helpers/dummy_data_helper'

module DataCycleCore
  module Api
    module V4
      class Thing < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper
        include DataCycleCore::V4::DummyDataHelper

        setup do
          @routes = Engine.routes
          @event = DataCycleCore::V4::DummyDataHelper.create_data('event')

          byebug
          @content_overlay.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_period: { start_date: 8.days.ago, end_date: 8.days.from_now } })
          image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
          image_data_hash['name'] = 'Another Image'
          overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

          place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi_de')
          place_data_hash['name'] = 'Another Place'
          overlay_place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: place_data_hash)

          @image_id = overlay_image.id
          @place_id = overlay_place.id
          @event_period = {
            'start_date' => '2019-11-10T00:00:00.000+01:00',
            'end_date' => '2019-11-20T00:00:00.000+01:00'
          }
          @data_hash = {
            'overlay' => [
              {
                'name' => 'overlay_name',
                'description' => '<p>overlay_description</p>',
                'image' => [overlay_image.id],
                'content_location' => [overlay_place.id],
                'url' => 'https://overlay.url.com',
                'event_schedule' => [{
                  'start_time' => {
                    'time' => Time.new(2019, 11, 10).in_time_zone,
                    'zone' => 'Vienna'
                  },
                  'duration' => 10.days.to_i
                }]
              }
            ]
          }
          @content_overlay.set_data_hash(data_hash: @data_hash, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
          @content_overlay.reload
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        def load_api_data(fields)
          get api_v4_thing_path(id: @content_overlay, fields: fields.join(','))
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          JSON.parse(response.body)
        end

        test 'another test' do
        end
      end
    end
  end
end
