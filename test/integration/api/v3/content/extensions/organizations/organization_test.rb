# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module Organizations
            class Organization < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('organization')
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
                assert_equal('http://schema.org', json_data['@context'])
                assert_equal('Organization', json_data['@type'])
                assert_equal('Organization', json_data['contentType'])
                assert_equal(root_url[0...-1] + api_v3_thing_path(id: @content), json_data['@id'])
                assert_equal(@content.id, json_data['identifier'])
                assert_equal(@content.created_at.as_json, json_data['dateCreated'])
                assert_equal(@content.updated_at.as_json, json_data['dateModified'])
                assert_equal(root_url[0...-1] + thing_path(@content), json_data['url'])

                # validity period
                # TODO: (move to generic tests)

                # classifications
                # TODO: (move to generic tests)
                assert(json_data['classifications'].present?)
                assert_equal(1, json_data['classifications'].size)
                classification_hash = json_data['classifications'].first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Organisation', classification_hash['name'])
                assert_equal(1, classification_hash['ancestors'].size)
                assert_equal(['Inhaltstypen'], classification_hash['ancestors'].pluck('name').sort)

                # language
                assert_equal('de', json_data['inLanguage'])

                # content data
                assert_equal(@content.name, json_data['legalName'])
                assert_equal(@content.description, json_data['description'])

                # add CountryCode Classification

                # TODO: (move to Transformations tests)
                # API: Transformation: address

                postal_address = @content.address.to_h.transform_keys { |key| key.camelize(:lower) }
                contact_info = @content.contact_info.to_h.transform_keys { |key| key.camelize(:lower) }
                address = { '@type' => 'PostalAddress' }.merge(postal_address).merge(contact_info)
                address['addressCountry'] = 'AT'
                assert_equal(address, json_data['address'])

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data['image'].first['identifier'])
              end

              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].detect { |item| item['@type'] == 'Organization' }
                assert_equal(@content.id, json_data['identifier'])

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].detect { |item| item['@type'] == 'Organization' }
                assert_equal(@content.id, json_data['identifier'])

                get(api_v3_organizations_path)
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

                excepted_params = ['@id', 'image']

                assert_equal(api_v3_json.except(*excepted_params), api_v2_json.except(*excepted_params))
                assert_equal(api_v3_json['image'].first.except(*excepted_params), api_v2_json['image'].first.except(*excepted_params))
              end
            end
          end
        end
      end
    end
  end
end
