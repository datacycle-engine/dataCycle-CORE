# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V2
      module Content
        module Extensions
          module Persons
            class Person < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.where(template: false).delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('person')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored person exists and is correct' do
                get api_v2_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body)

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('Person', json_data.dig('@type'))
                assert_equal('Person', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v2_thing_path(id: @content), json_data.dig('@id'))
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
                assert_equal('Person', classification_hash.dig('name'))
                assert_equal(1, classification_hash.dig('ancestors').size)
                assert_equal(['Inhaltstypen'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

                # language
                assert_equal('de', json_data.dig('inLanguage'))

                # content data
                assert_equal(@content.given_name, json_data.dig('givenName'))
                assert_equal(@content.family_name, json_data.dig('familyName'))
                assert_equal(@content.honorific_prefix, json_data.dig('honorificPrefix'))
                assert_equal(@content.honorific_suffix, json_data.dig('honorificSuffix'))
                assert_equal(@content.job_title, json_data.dig('jobTitle'))
                assert_equal(@content.description, json_data.dig('description'))

                # add CountryCode Classification

                # TODO: (move to Transformations tests)
                # API: Transformation: address

                postal_address = @content.address.to_h.transform_keys { |key| key.camelize(:lower) }
                contact_info = @content.contact_info.to_h.transform_keys { |key| key.camelize(:lower) }
                address = { '@type' => 'PostalAddress' }.merge(postal_address).merge(contact_info)
                address['addressCountry'] = 'AT'

                assert_equal(address, json_data.dig('address'))

                # TODO: (move to Transformations tests)
                # API: Transformation: GenderType
                gender_json = {
                  '@type' => 'GenderType',
                  'name' => 'Male'
                }
                assert_equal(gender_json, json_data.dig('gender').first)

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data.dig('image').first.dig('identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v2_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| item.dig('@type') == 'Person' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v2_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| item.dig('@type') == 'Person' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v2_persons_path)
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
