# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module Places
            class Poi < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('poi')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              # TODO: Add tests for overlay, openingHoursSpecification
              test 'json of stored item exists and is correct' do
                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body)

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('TouristAttraction', json_data.dig('@type').last)
                assert_equal('POI', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v3_thing_path(id: @content), json_data.dig('@id'))
                assert_equal(@content.id, json_data.dig('identifier'))
                assert_equal(@content.created_at.as_json, json_data.dig('dateCreated'))
                assert_equal(@content.updated_at.as_json, json_data.dig('dateModified'))
                assert_equal(root_url[0...-1] + thing_path(@content), json_data.dig('url'))

                # validity period

                # classifications
                assert(json_data.dig('classifications').present?)
                assert_equal(1, json_data.dig('classifications').size)
                classification_hash = json_data.dig('classifications').first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('POI', classification_hash.dig('name'))
                assert_equal(2, classification_hash.dig('ancestors').size)
                assert_equal(['Inhaltstypen', 'Ort'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

                # language
                assert_equal('de', json_data.dig('inLanguage'))

                # content data
                assert_equal(@content.name, json_data.dig('name'))
                assert_equal(@content.description, json_data.dig('description'))

                # TODO: (move to Transformations tests)
                # API: Transformation: additionalProperty
                assert_equal(@content.text, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'text' }.dig('value'))

                # TODO: (move to Transformations tests)
                # API: Transformation: address
                geo = {
                  '@type' => 'GeoCoordinates',
                  'longitude' => @content.longitude,
                  'latitude' => @content.latitude,
                  'elevation' => @content.elevation
                }
                assert_equal(geo, json_data.dig('geo'))

                # TODO: (move to Transformations tests)
                # API: Transformation: address
                postal_address = @content.address.to_h.transform_keys { |key| key.camelize(:lower) }
                contact_info = @content.contact_info.to_h.transform_keys { |key| key.camelize(:lower) }
                address = { '@type' => 'PostalAddress' }.merge(postal_address).merge(contact_info)
                address['addressCountry'] = 'AT'

                assert_equal(address, json_data.dig('address'))

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data.dig('image').first.dig('identifier'))
                assert_equal(@content.primary_image.first.id, json_data.dig('photo').first.dig('identifier'))
                assert_equal(@content.logo.first.id, json_data.dig('logo').first.dig('identifier'))

                # Validate OpeningHoursSpecification
                expected_opening_hours_specification_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_specification_result')
                expected_opening_hours_description_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_description_result')

                assert_equal(expected_opening_hours_specification_hash, json_data.dig('openingHoursSpecification'))
                assert_equal(expected_opening_hours_description_hash, json_data.dig('dc:openingHoursDescription'))
              end

              test 'testing PlaceOverlay' do
                image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
                image_data_hash['name'] = 'Another Image'
                overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

                data_hash = {
                  'name' => 'original_name',
                  'description' => 'original_description',
                  'text' => 'original_text',
                  'overlay' => [{
                    'name' => 'overlay_name',
                    'description' => '<p>overlay_description</p>',
                    'text' => 'overlay_text',
                    'image' => [overlay_image.id]
                  }]
                }
                I18n.with_locale(:de) do
                  @content.set_data_hash(data_hash: data_hash, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
                end
                @content.reload

                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body)

                # content data
                assert_equal(data_hash.dig('overlay').first.dig('name'), json_data.dig('name'))
                assert_equal(data_hash.dig('overlay').first.dig('description'), json_data.dig('description'))
                assert_equal(1, json_data.dig('additionalProperty').size)
                assert_equal(data_hash.dig('overlay').first.dig('text'), json_data.dig('additionalProperty').first.dig('value'))
                assert_equal(overlay_image.id, json_data.dig('photo').first.dig('identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| Array.wrap(item.dig('@type')).last == 'TouristAttraction' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| Array.wrap(item.dig('@type')).last == 'TouristAttraction' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_places_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').first
                assert_equal(@content.id, json_data.dig('identifier'))
              end

              test 'APIv2 json equals APIv3 json result' do
                get api_v2_thing_path(id: @content)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                api_v2_json = JSON.parse(response.body)

                get api_v3_thing_path(id: @content)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                api_v3_json = JSON.parse(response.body)

                # openingHoursSpecification has been changed in APIv3
                excepted_params = ['@id', 'image', 'photo', 'logo', 'openingHoursSpecification', 'potentialAction', 'additionalInformation']

                assert_equal(api_v3_json.except(*excepted_params), api_v2_json.except(*excepted_params))
                assert_equal(api_v3_json.dig('image').first.except(*excepted_params), api_v2_json.dig('image').first.except(*excepted_params))
                assert_equal(api_v3_json.dig('photo').first.except(*excepted_params), api_v2_json.dig('photo').first.except(*excepted_params))
                assert_equal(api_v3_json.dig('logo').first.except(*excepted_params), api_v2_json.dig('logo').first.except(*excepted_params))
              end
            end
          end
        end
      end
    end
  end
end
