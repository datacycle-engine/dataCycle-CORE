# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class OverlayTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::ApiV4Helper

          before(:all) do
            @routes = Engine.routes
            @content_overlay = DataCycleCore::DummyDataHelper.create_data('event')
            event_schedule = @content_overlay.get_data_hash
            event_schedule['event_schedule'] = [{
              'start_time' => {
                'time' => 8.days.ago.to_s,
                'zone' => 'Europe/Vienna'
              },
              'duration' => 10.days.to_i
            }]
            @content_overlay.set_data_hash(prevent_history: true, data_hash: event_schedule)
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'testing EventOverlay' do
            image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
            image_data_hash['name'] = 'Another Image'
            overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

            place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi_de')
            place_data_hash['name'] = 'Another Place'
            overlay_place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: place_data_hash)

            data_hash = {
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
            event_period = {
              'start_date' => '2019-11-10T00:00:00.000+01:00',
              'end_date' => '2019-11-20T00:00:00.000+01:00'
            }
            I18n.with_locale(:de) do
              new_data_hash = @content_overlay.get_data_hash.merge(data_hash)
              @content_overlay.set_data_hash(data_hash: new_data_hash, current_user: User.find_by(email: 'tester@datacycle.at'))
            end
            @content_overlay.reload

            get api_v4_thing_path(id: @content_overlay)

            assert_response(:success)
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body.dig('@graph').first
            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content_overlay)
            assert_equal(header.except('name'), data.except('name'))

            ['image', 'location'].each do |embedded|
              assert_compact_header(json_data.dig(embedded.camelize(:lower)))
            end

            # content data
            assert_equal(event_period['start_date'], json_data.dig('startDate'))
            assert_equal(event_period['end_date'], json_data.dig('endDate'))
            assert_equal(data_hash.dig('overlay', 0, 'name'), json_data.dig('name'))
            assert_equal(data_hash.dig('overlay', 0, 'description'), json_data.dig('description'))
            assert_equal(data_hash.dig('overlay', 0, 'url'), json_data.dig('sameAs'))
            assert_equal(overlay_image.id, json_data.dig('image', 0, '@id'))
            assert_equal(overlay_place.id, json_data.dig('location', 0, '@id'))

            # attribute link is rendered in additionalProperty
            assert(json_data.dig('additionalProperty').present?)
            assert_equal('PropertyValue', json_data.dig('additionalProperty', 0, '@type'))
            assert_equal('Link', json_data.dig('additionalProperty', 0, 'name'))
            assert_equal('link', json_data.dig('additionalProperty', 0, 'identifier'))
            assert_equal(@content_overlay.same_as, json_data.dig('additionalProperty', 0, 'value'))
          end
        end
      end
    end
  end
end
