# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module Places
            class Tour < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('tour')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored item exists and is correct' do
                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body

                # validate header
                assert_equal('http://schema.org', json_data['@context'])
                assert_equal('Place', json_data['@type'])
                assert_equal('Tour', json_data['contentType'])
                assert_equal(root_url[0...-1] + api_v3_thing_path(id: @content), json_data['@id'])
                assert_equal(@content.id, json_data['identifier'])
                assert_equal(@content.created_at.as_json, json_data['dateCreated'])
                assert_equal(@content.updated_at.as_json, json_data['dateModified'])
                assert_equal(root_url[0...-1] + thing_path(@content), json_data['url'])

                # classifications
                assert(json_data['classifications'].present?)
                assert_equal(1, json_data['classifications'].size)
                classification_hash = json_data['classifications'].first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Tour', classification_hash['name'])
                assert_equal(2, classification_hash['ancestors'].size)
                assert_equal(['Inhaltstypen', 'Ort'], classification_hash['ancestors'].pluck('name').sort)

                # language
                assert_equal('de', json_data['inLanguage'])

                # content
                assert_equal(@content.name, json_data['name'])
                assert_equal(@content.description, json_data['description'])
                assert_equal([6], json_data['schedule'].first['byMonth'])

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data['image'].first['identifier'])
                assert_equal(@content.primary_image.first.id, json_data['primaryImage'].first['identifier'])
                assert_equal(@content.logo.first.id, json_data['logo'].first['identifier'])
              end

              # test fails because no ordering = random
              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].detect { |item| item['@type'] == 'Place' }
                assert_equal(@content.id, json_data['identifier'])

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].detect { |item| item['@type'] == 'Place' }
                assert_equal(@content.id, json_data['identifier'])

                get(api_v3_places_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].first
                assert_equal(@content.id, json_data['identifier'])
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

                # openingHoursSpecification has been changed in APIv3
                excepted_params = ['@id', 'image', 'primaryImage', 'logo', 'schedule', 'poi', 'externalIdentifier', 'additionalInformation', 'aggregateRating', 'author', 'additionalProperty', 'odta:wayPoint']
                excepted_params += ['inLanguage', 'identifier']

                assert_equal(api_v3_json.except(*excepted_params), api_v2_json.except(*excepted_params))
                # linked
                assert_equal(api_v3_json['image'].first.except(*excepted_params), api_v2_json['image'].first.except(*excepted_params))
                assert_equal(api_v3_json['primaryImage'].first.except(*excepted_params), api_v2_json['primaryImage'].first.except(*excepted_params))
                assert_equal(api_v3_json['logo'].first.except(*excepted_params), api_v2_json['logo'].first.except(*excepted_params))
                assert_equal(api_v3_json['poi'].first.except(*excepted_params), api_v2_json['poi'].first.except(*excepted_params))
                # embedded
                assert_equal(api_v3_json['additionalInformation'].first.except(*excepted_params), api_v2_json['additionalInformation'].first.except(*excepted_params))
              end
            end
          end
        end
      end
    end
  end
end
