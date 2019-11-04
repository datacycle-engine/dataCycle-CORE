# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class FieldsTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        setup do
          @routes = Engine.routes
          @content_overlay = DataCycleCore::DummyDataHelper.create_data('event')
          @content_overlay.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_period: { start_date: 8.days.ago, end_date: 8.days.from_now } })
          image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
          image_data_hash['name'] = 'Another Image'
          overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

          place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi')
          place_data_hash['name'] = 'Another Place'
          overlay_place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: place_data_hash)

          @image_id = overlay_image.id
          @place_id = overlay_place.id
          @data_hash = {
            'overlay' => [
              {
                'name' => 'overlay_name',
                'description' => '<p>overlay_description</p>',
                'image' => [overlay_image.id],
                'content_location' => [overlay_place.id],
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

        def load_api_data(fields)
          get api_v4_thing_path(id: @content_overlay, fields: fields.join(','))
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          JSON.parse(response.body)
        end

        def default_fields
          ['@id', '@language', '@type']
        end

        test 'testing EventOverlay with fields parameter (filtering unstructured data)' do
          fields = ['name', 'dc:entity_url']
          json_data = load_api_data(fields)
          assert_equal(['@context', '@graph'], json_data.keys.sort)
          assert_equal((fields + default_fields).sort, json_data.dig('@graph', 0).keys.sort)
        end

        test 'testing EventOverlay with fields parameter (filtering objects)' do
          fields = ['eventPeriod']
          json_data = load_api_data(fields)

          assert_equal(['@context', '@graph'], json_data.keys.sort)
          assert_equal((fields + default_fields).sort, json_data.dig('@graph', 0).keys.sort)
          assert_equal(@data_hash.dig('overlay', 0, 'event_period', 'start_date'), json_data.dig('@graph', 0, 'eventPeriod', 'startDate'))
          assert_equal(@data_hash.dig('overlay', 0, 'event_period', 'end_date'), json_data.dig('@graph', 0, 'eventPeriod', 'endDate'))
        end

        test 'testing EventOverlay with fields parameter (filtering additionalProperty)' do
          fields = ['additionalProperty']
          json_data = load_api_data(fields)

          assert_equal(['@context', '@graph'], json_data.keys.sort)
          assert_equal((fields + default_fields).sort, json_data.dig('@graph', 0).keys.sort)
          assert_equal('PropertyValue', json_data.dig('@graph', 0, 'additionalProperty', 0, '@type'))
          assert_equal('Link', json_data.dig('@graph', 0, 'additionalProperty', 0, 'name'))
          assert_equal('link', json_data.dig('@graph', 0, 'additionalProperty', 0, 'identifier'))
          assert_equal(@content_overlay.same_as, json_data.dig('@graph', 0, 'additionalProperty', 0, 'value'))
        end

        test 'testing EventOverlay with fields parameter (filtering linked/embedded data --> no data linked/embedded are no fields)' do
          fields = ['image', 'subEvent']
          json_data = load_api_data(fields)

          assert_equal(['@context', '@graph'], json_data.keys.sort)
          assert_equal(default_fields.sort, json_data.dig('@graph', 0).keys.sort)
        end
      end
    end
  end
end
