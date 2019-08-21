# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class IncludeTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        setup do
          @routes = Engine.routes
          @content_overlay = DataCycleCore::DummyDataHelper.create_data('event')
          sign_in(User.find_by(email: 'tester@datacycle.at'))
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
            @content_overlay.set_data_hash(data_hash: data_hash, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
          end
          @content_overlay.reload

          get api_v4_thing_path(id: @content_overlay)

          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data = JSON.parse(response.body)
          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content_overlay)
          assert_equal(header, data)

          ['image', 'sub_event', 'location'].each do |embedded|
            assert_compact_header(json_data.dig(embedded.camelize(:lower)))
          end

          # content data
          assert_equal(data_hash.dig('overlay', 0, 'event_period', 'start_date'), json_data.dig('eventPeriod', 'startDate'))
          assert_equal(data_hash.dig('overlay', 0, 'event_period', 'end_date'), json_data.dig('eventPeriod', 'endDate'))
          assert_equal(data_hash.dig('overlay', 0, 'name'), json_data.dig('name'))
          assert_equal(data_hash.dig('overlay', 0, 'description'), json_data.dig('description'))
          assert_equal(data_hash.dig('overlay', 0, 'url'), json_data.dig('sameAs'))
          assert_equal(api_v4_thing_url(id: overlay_image.id), json_data.dig('image', 0, '@id'))
          assert_equal(api_v4_thing_url(id: overlay_place.id), json_data.dig('location', 0, '@id'))

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
