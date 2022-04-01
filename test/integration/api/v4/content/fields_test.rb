# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class FieldsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::ApiV4Helper

          before(:all) do
            @routes = Engine.routes
            @content_overlay = DataCycleCore::DummyDataHelper.create_data('event')
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
                      'zone' => 'Europe/Vienna'
                    },
                    'duration' => 10.days.to_i
                  }]
                }
              ]
            }
            @content_overlay.set_data_hash(data_hash: @data_hash, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
            @content_overlay.reload
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          def load_api_data(fields)
            get api_v4_thing_path(id: @content_overlay, fields: fields.join(','))
            assert_response(:success)
            assert_equal('application/json; charset=utf-8', response.content_type)
            JSON.parse(response.body).dig('@graph').first
          end

          def default_fields
            ['@id', '@type']
          end

          test 'testing EventOverlay with fields parameter (filtering unstructured data)' do
            fields = ['dc:entityUrl']
            json_data = load_api_data(fields)
            assert_equal((fields + default_fields).sort, json_data.keys.sort)
          end

          test 'testing EventOverlay with fields parameter (filtering objects)' do
            fields = ['startDate', 'endDate']
            json_data = load_api_data(fields)

            assert_equal((fields + default_fields).sort, json_data.keys.sort)
            assert_equal(@event_period.dig('start_date'), json_data.dig('startDate'))
            assert_equal(@event_period.dig('end_date'), json_data.dig('endDate'))
          end

          test 'testing EventOverlay with fields parameter (filtering additionalProperty)' do
            fields = ['additionalProperty']
            json_data = load_api_data(fields)

            assert_equal((fields + default_fields).sort, json_data.keys.sort)
            assert_equal(['@type', 'identifier', 'name', '@id', 'value'], json_data.dig('additionalProperty', 0).keys)
            assert_equal('PropertyValue', json_data.dig('additionalProperty', 0, '@type'))
          end

          test 'testing EventOverlay with fields parameter (filtering additionalProperty.name)' do
            fields = ['additionalProperty.name']
            json_data = load_api_data(fields)

            assert_equal((['additionalProperty'] + default_fields).sort, json_data.keys.sort)
            assert_equal(['@type', 'name', '@id'], json_data.dig('additionalProperty', 0).keys)
            assert_equal('PropertyValue', json_data.dig('additionalProperty', 0, '@type'))
          end

          # TODO: subEvent does not exists anymore in APIv4 (legacy property)
          test 'testing EventOverlay with fields parameter (filtering linked/embedded data --> linked rendered with default header)' do
            fields = ['image', 'subEvent']
            json_data = load_api_data(fields)
            assert_equal((default_fields + ['image']).sort, json_data.keys.sort)
          end
        end
      end
    end
  end
end
