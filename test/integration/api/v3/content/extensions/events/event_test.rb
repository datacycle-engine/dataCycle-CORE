# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module Events
            class Event < ActionDispatch::IntegrationTest
              include Devise::Test::IntegrationHelpers
              include Engine.routes.url_helpers

              setup do
                @routes = Engine.routes

                image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
                @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

                place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi')
                place_data_hash[:image] = @image.id
                @place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: place_data_hash)

                event_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'api_event')
                event_data_hash[:image] = [@image.id]
                event_data_hash[:content_location] = [@place.id]
                @content = DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: event_data_hash)

                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored content exists and is correct' do
                get api_v3_thing_path(@content)

                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body)

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('Event', json_data.dig('@type'))
                assert_equal('Event', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v3_thing_path(@content), json_data.dig('@id'))
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
                assert_equal(@content.event_period.start_date, json_data.dig('startDate'))
                assert_equal(@content.event_period.end_date, json_data.dig('endDate'))

                # content data
                assert_equal(@content.name, json_data.dig('name'))
                assert_equal(@content.description, json_data.dig('description'))
                assert_equal(@content.url, json_data.dig('sameAs'))
                assert_equal(@content.same_as, json_data.dig('additionalProperty').select { |item| item.dig('identifier') == 'link' }.first.dig('value'))

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data.dig('image').first.dig('identifier'))
                assert_equal(@content.content_location.first.id, json_data.dig('location').first.dig('identifier'))

                # sub_events
                sub_events = @content.sub_event.map do |sub_event|
                  {
                    '@context' => 'http://schema.org',
                    '@type' => 'Event',
                    'contentType' => 'SubEvent',
                    'name' => sub_event.name,
                    'description' => sub_event.description,
                    'sameAs' => sub_event.url,
                    'startDate' => sub_event.event_period.start_date,
                    'endDate' => sub_event.event_period.end_date
                  }
                end
                assert_equal(sub_events, json_data.dig('subEvent'))
              end

              test 'testing EventOverlay' do
                image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
                image_data_hash['name'] = 'Another Image'
                overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

                place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi')
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
                      'event_period' => {
                        'start_date' => '2019-11-10T00:00:00.000+01:00',
                        'end_date' => '2019-11-20T00:00:00.000+01:00'
                      }
                    }
                  ]
                }
                I18n.with_locale(:de) do
                  @content.set_data_hash(data_hash: data_hash, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
                end
                @content.reload

                get api_v3_thing_path(@content)

                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body)

                # content data
                assert_equal(data_hash.dig('overlay').first.dig('event_period', 'start_date'), json_data.dig('startDate'))
                assert_equal(data_hash.dig('overlay').first.dig('event_period', 'end_date'), json_data.dig('endDate'))
                assert_equal(data_hash.dig('overlay').first.dig('name'), json_data.dig('name'))
                assert_equal(data_hash.dig('overlay').first.dig('description'), json_data.dig('description'))
                assert_equal(data_hash.dig('overlay').first.dig('url'), json_data.dig('sameAs'))
                assert_equal(overlay_image.id, json_data.dig('image').first.dig('identifier'))
                assert_equal(overlay_place.id, json_data.dig('location').first.dig('identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body).dig('data').select { |item| item.dig('@type') == 'Event' }.first
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body).dig('data').select { |item| item.dig('@type') == 'Event' }.first
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_events_path)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body).dig('data').first
                assert_equal(@content.id, json_data.dig('identifier'))
              end

              test 'APIv2 json equals APIv3 json result' do
                get api_v2_thing_path(@content)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                api_v2_json = JSON.parse(response.body)

                get api_v3_thing_path(@content)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                api_v3_json = JSON.parse(response.body)

                excepted_params = ['@id', 'image', 'location']

                assert_equal(api_v3_json.except(*excepted_params), api_v2_json.except(*excepted_params))
                assert_equal(api_v3_json.dig('image').first.except(*excepted_params), api_v2_json.dig('image').first.except(*excepted_params))
              end
            end
          end
        end
      end
    end
  end
end
