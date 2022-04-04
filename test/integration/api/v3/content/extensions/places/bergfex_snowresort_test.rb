# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module Places
            class BergfexSnowResortTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.where(template: false).delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('bergfex_snowresort')
              end

              setup do
                sign_in(User.find_by(email: 'admin@datacycle.at'))
              end

              # TODO: Add tests for overlay, openingHoursSpecification
              test 'json of stored item exists and is correct' do
                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body)

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('SkiResort', json_data.dig('@type').last)
                assert_equal('Skigebiet', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v3_thing_path(id: @content), json_data.dig('@id'))
                assert_equal(@content.id, json_data.dig('identifier'))
                assert_equal(@content.created_at.as_json, json_data.dig('dateCreated'))
                assert_equal(@content.updated_at.as_json, json_data.dig('dateModified'))

                # classifications
                assert(json_data.dig('classifications').present?)
                assert_equal(1, json_data.dig('classifications').size)
                classification_hash = json_data.dig('classifications').first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Skigebiet', classification_hash.dig('name'))
                assert_equal(2, classification_hash.dig('ancestors').size)
                assert_equal(['Inhaltstypen', 'Ort'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)
                assert_equal(root_url[0...-1] + thing_path(@content), json_data.dig('url'))

                # language
                assert_equal('de', json_data.dig('inLanguage'))

                # content data
                assert_equal(@content.name, json_data.dig('name'))
                assert_equal(@content.same_as, json_data.dig('sameAs'))

                # TODO: (move to Transformations tests)
                # API: Transformation: address
                geo = {
                  '@type' => 'GeoCoordinates',
                  'longitude' => @content.longitude,
                  'latitude' => @content.latitude
                }
                assert_equal(geo, json_data.dig('geo'))

                # Validate OpeningHoursSpecification
                expected_opening_hours_specification_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_specification_result')
                assert_equal(expected_opening_hours_specification_hash, json_data.dig('openingHoursSpecification'))

                # additionalProperty
                assert_equal(@content.date_time_updated_at, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'dateTimeUpdatedAt' }.dig('value'))
                assert_equal(@content.date_last_snowfall, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'dateLastSnowfall' }.dig('value'))
                assert_equal(@content.length_nordic_classic, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'lengthNordicClassic' }.dig('value'))
                assert_equal(@content.length_nordic_skating, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'lengthNordicSkating' }.dig('value'))
                assert_equal(@content.lifts.value, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'lifts' }.dig('value'))
                assert_equal(@content.lifts.max_value, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'lifts' }.dig('maxValue'))
                assert_equal(@content.slopes.value, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'slopes' }.dig('value'))
                assert_equal(@content.slopes.max_value, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'slopes' }.dig('maxValue'))
                assert_equal(@content.count_open_slopes.value, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'countOpenSlopes' }.dig('value'))
                assert_equal(@content.count_open_slopes.max_value, json_data.dig('additionalProperty').detect { |item| item.dig('identifier') == 'countOpenSlopes' }.dig('maxValue'))

                amenity_feature = @content.addons.map do |addon|
                  {
                    '@context' => 'http://schema.org',
                    '@type' => ['Intangible', 'StructuredValue', 'PropertyValue', 'LocationFeatureSpecification'],
                    'contentType' => 'Skigebiet - Addon',
                    'identifier' => addon.id,
                    'inLanguage' => 'de',
                    'headline' => addon.name,
                    'value' => addon.text
                  }
                end
                assert_equal(amenity_feature, json_data.dig('amenityFeature'))

                contains_place = @content.snow_report.map do |snow_report|
                  additional_properties = []
                  if snow_report.depth_of_snow.present?
                    additional_properties << {
                      '@type' => 'PropertyValue',
                      'identifier' => 'depthOfSnow',
                      'name' => 'Schneehöhe',
                      'value' => snow_report.depth_of_snow
                    }
                  end

                  if snow_report.depth_of_fresh_snow.present?
                    additional_properties << {
                      '@type' => 'PropertyValue',
                      'identifier' => 'depthOfFreshSnow',
                      'name' => 'Neuschnee',
                      'value' => snow_report.depth_of_fresh_snow
                    }
                  end

                  {
                    'name' => snow_report.name,
                    'geo' => {
                      '@type' => 'GeoCoordinates',
                      'elevation' => snow_report.elevation
                    },
                    'additionalProperty' => additional_properties
                  }
                end

                assert_equal('http://schema.org', json_data.dig('containsPlace').first.dig('@context'))
                assert_equal('Place', json_data.dig('containsPlace').first.dig('@type'))
                assert_equal('Schneehöhe - Messpunkt', json_data.dig('containsPlace').first.dig('contentType'))
                assert_equal(contains_place.first.dig('name'), json_data.dig('containsPlace').first.dig('name'))
                assert_equal(contains_place.first.dig('geo'), json_data.dig('containsPlace').first.dig('geo'))
                assert_equal(contains_place.first.dig('additionalProperty'), json_data.dig('containsPlace').first.dig('additionalProperty'))
              end

              test 'testing PlaceOverlay' do
                image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
                image_data_hash['name'] = 'Another Image'
                overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

                data_hash = {
                  'overlay' => [{
                    'name' => 'overlay_name',
                    'same_as' => 'LINK URL',
                    'image' => [overlay_image.id]
                  }]
                }
                I18n.with_locale(:de) do
                  @content.set_data_hash(data_hash: data_hash, partial_update: true, current_user: DataCycleCore::User.find_by(email: 'tester@datacycle.at'))
                end
                @content.reload

                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body)

                # content data
                assert_equal(data_hash.dig('overlay').first.dig('name'), json_data.dig('name'))
                assert_equal(data_hash.dig('overlay').first.dig('same_as'), json_data.dig('sameAs'))
                assert_equal(overlay_image.id, json_data.dig('image').first.dig('identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| Array.wrap(item.dig('@type')).last == 'SkiResort' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| Array.wrap(item.dig('@type')).last == 'SkiResort' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_places_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').first
                assert_equal(@content.id, json_data.dig('identifier'))
              end
            end
          end
        end
      end
    end
  end
end
