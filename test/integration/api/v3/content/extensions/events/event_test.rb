# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module Events
            class Event < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('event')
                event_schedule = @content.get_data_hash
                event_schedule['event_schedule'] = [{
                  'start_time' => {
                    'time' => Time.new(2019, 10, 10).in_time_zone,
                    'zone' => 'Europe/Vienna'
                  },
                  'rtimes' => [{
                    'time' => Time.new(2019, 10, 10).in_time_zone,
                    'zone' => 'Europe/Vienna'
                  }, {
                    'time' => Time.new(2019, 10, 20).in_time_zone,
                    'zone' => 'Europe/Vienna'
                  }],
                  'duration' => 5.days.to_i
                }]
                @content.set_data_hash(prevent_history: true, data_hash: event_schedule)
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored content exists and is correct' do
                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('Event', json_data.dig('@type'))
                assert_equal('Event', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v3_thing_path(id: @content), json_data.dig('@id'))
                assert_equal(@content.id, json_data.dig('identifier'))
                assert_equal(@content.created_at.as_json, json_data.dig('dateCreated'))
                assert_equal(@content.updated_at.as_json, json_data.dig('dateModified'))
                assert_equal(root_url[0...-1] + thing_path(@content), json_data.dig('url'))

                # validity period
                # TODO: (move to generic tests)

                # classifications
                # TODO: (move to generic tests)
                assert(json_data.dig('classifications').present?)
                assert_equal(1, json_data.dig('classifications').size)
                classification_hash = json_data.dig('classifications').first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Veranstaltung', classification_hash.dig('name'))
                assert_equal(1, classification_hash.dig('ancestors').size)
                assert_equal(['Inhaltstypen'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

                # language
                assert_equal('de', json_data.dig('inLanguage'))

                # startDate / endDate
                assert_equal(@content.start_date.as_json, json_data.dig('startDate'))
                assert_equal(@content.end_date.as_json, json_data.dig('endDate'))

                # content data
                assert_equal(@content.name, json_data.dig('name'))
                assert_equal(@content.description, json_data.dig('description'))
                assert_equal(@content.url, json_data.dig('sameAs'))
                assert_equal(@content.same_as, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'link' }.dig('value'))

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data.dig('image').first.dig('identifier'))
                assert_equal(@content.content_location.first.id, json_data.dig('location').first.dig('identifier'))
              end

              test 'test subevents vs. generated from event_schedule' do
                # set event_schedule with proper data
                event_schedule = @content.event_schedule.first
                event_schedule_hash = event_schedule.to_sub_event
                event_schedule_hash = event_schedule_hash.map { |i| i.except('identifier') }

                # sub_events
                sub_events = @content.sub_event.map do |sub_event|
                  {
                    '@context' => 'http://schema.org',
                    '@type' => 'Event',
                    'contentType' => 'SubEvent',
                    'inLanguage' => 'de',
                    'startDate' => sub_event.event_period.start_date.to_fs(:long_msec),
                    'endDate' => sub_event.event_period.end_date.to_fs(:long_msec)
                  }
                end
                assert_equal(sub_events, event_schedule_hash)
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
                      'event_schedule' => [
                        {
                          'start_time' =>
                          {
                            'time' => '2019-11-10T00:00:00.000+01:00'.in_time_zone.to_s,
                            'zone' => 'Europe/Vienna'
                          },
                          'duration' => 10.days.to_i
                        }
                      ]
                    }
                  ]
                }
                I18n.with_locale(:de) do
                  @content.set_data_hash(data_hash:, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
                end
                @content.reload

                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body

                # content data
                assert_equal(data_hash.dig('overlay').first.dig('event_schedule', 0, 'start_time', 'time').in_time_zone, json_data.dig('startDate'))
                assert_equal((data_hash.dig('overlay').first.dig('event_schedule', 0, 'start_time', 'time').in_time_zone + data_hash.dig('overlay').first.dig('event_schedule', 0, 'duration').to_i), json_data.dig('endDate'))
                assert_equal(data_hash.dig('overlay').first.dig('name'), json_data.dig('name'))
                assert_equal(data_hash.dig('overlay').first.dig('description'), json_data.dig('description'))
                assert_equal(data_hash.dig('overlay').first.dig('url'), json_data.dig('sameAs'))
                assert_equal(overlay_image.id, json_data.dig('image').first.dig('identifier'))
                assert_equal(overlay_place.id, json_data.dig('location').first.dig('identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body.dig('data').detect { |item| item.dig('@type') == 'Event' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body.dig('data').detect { |item| item.dig('@type') == 'Event' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_events_path(filter: { from: '2019-10-01' }))
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body.dig('data').first
                assert_equal(@content.id, json_data.dig('identifier'))
              end

              test 'APIv2 json equals APIv3 json result' do
                get api_v2_thing_path(id: @content)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                api_v2_json = response.parsed_body

                get api_v3_thing_path(id: @content)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                api_v3_json = response.parsed_body

                excepted_params = ['@id', 'image', 'location']

                v3_subevents = @content.sub_event.map do |sub_event|
                  {
                    '@context' => 'http://schema.org',
                    '@type' => 'Event',
                    'contentType' => 'SubEvent',
                    'inLanguage' => 'de',
                    'identifier' => sub_event.id,
                    'startDate' => sub_event.event_period.start_date.to_fs(:long_msec),
                    'endDate' => sub_event.event_period.end_date.to_fs(:long_msec)
                  }
                end
                v2_subevents = v3_subevents.map do |sub_event|
                  sub_event.except('identifier', 'inLanguage')
                end
                convert_api_v2_json = api_v2_json
                convert_api_v2_json['subEvent'].map do |item|
                  item['startDate'] = item['startDate'].in_time_zone.to_fs(:long_msec)
                  item['endDate'] = item['endDate'].in_time_zone.to_fs(:long_msec)
                end
                convert_api_v3_json = api_v3_json
                convert_api_v3_json['subEvent'].map do |item|
                  item['startDate'] = item['startDate'].in_time_zone.to_fs(:long_msec)
                  item['endDate'] = item['endDate'].in_time_zone.to_fs(:long_msec)
                end
                except_sub_event_params = excepted_params + ['identifier', 'name', 'description', 'sameAs']

                assert_equal(api_v3_json.except('subEvent', 'eventSchedule', *except_sub_event_params), api_v2_json.except('subEvent', 'eventSchedule', *except_sub_event_params))
                assert_equal(1, api_v3_json.dig('eventSchedule').size)
                assert_equal(1, api_v2_json.dig('eventSchedule').size)
                assert_equal(convert_api_v2_json.dig('subEvent').map { |item| item.except(*except_sub_event_params) }, v2_subevents.map { |item| item.except(*except_sub_event_params) })
                assert_equal(convert_api_v3_json.dig('subEvent').map { |item| item.except(*except_sub_event_params) }, v3_subevents.map { |item| item.except(*except_sub_event_params) })
                assert_equal(api_v3_json.dig('image').first.except(*except_sub_event_params), api_v2_json.dig('image').first.except(*except_sub_event_params))
              end
            end
          end
        end
      end
    end
  end
end
