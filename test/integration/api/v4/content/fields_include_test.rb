# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class FieldsIncludeTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::ApiV4Helper

          before(:all) do
            @routes = Engine.routes
            @content_overlay = DataCycleCore::DummyDataHelper.create_data('event')
            @content_overlay.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_period: { start_date: 8.days.ago, end_date: 8.days.from_now } })
            image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
            image_data_hash['name'] = 'Another Image'
            @overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

            place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi_de')
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
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          def load_api_data(fields, includes)
            get api_v4_thing_path(id: @content_overlay, fields: fields&.join(','), include: includes&.join(','))
            assert_response(:success)
            assert_equal('application/json; charset=utf-8', response.content_type)
            response.parsed_body.dig('@graph').first
          end

          def add_default(array)
            (['@id', '@type'] + array).sort
          end

          def add_header(array)
            (['@id', '@type'] + array).sort
          end

          test 'testing EventOverlay with fields and include parameter (only fields in main objext --> no incuded data)' do
            fields = ['name']
            includes = ['image', 'location', 'subEvent']
            json_data = load_api_data(fields, includes)
            assert_equal(add_default(['name', 'image', 'location']), json_data.keys.sort)
          end

          test 'testing EventOverlay with fields and include parameter (one included data)' do
            fields = ['image.name']
            # includes now possible in addition to fields
            includes = ['image', 'location', 'subEvent']
            json_data = load_api_data(fields, includes)

            assert_equal(add_default(['image', 'location']), json_data.keys.sort)
            assert_equal(add_header(['name']), json_data.dig('image', 0).keys.sort)
            assert_equal(@overlay_image.name, json_data.dig('image', 0, 'name'))
          end

          # TODO: subEvent does not exists anymore in APIv4 (legacy property)
          test 'testing EventOverlay with fields and include parameter fields rendered with default header + property' do
            # image.name is valid. Is equal to fields=image
            fields = ['image.name', 'name']
            # subEvent does not exists anymore in APIv4 (legacy property)
            includes = ['location', 'subEvent']
            json_data = load_api_data(fields, includes)

            assert_equal(add_default(['image', 'location', 'name']), json_data.keys.sort)
          end
        end
      end
    end
  end
end
