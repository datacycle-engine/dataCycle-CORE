# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V2
      module Content
        module Extensions
          module CreativeWorks
            class Audio < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('audio')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored image exists and is correct' do
                get api_v2_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body

                # validate header
                assert_equal('http://schema.org', json_data['@context'])
                assert_equal('AudioObject', json_data['@type'].last)
                assert_equal('Audio', json_data['contentType'])
                assert_equal(root_url[0...-1] + api_v2_thing_path(id: @content), json_data['@id'])
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
                assert_equal('Audio', classification_hash['name'])
                assert_equal(2, classification_hash['ancestors'].size)
                assert_equal(['Asset', 'Inhaltstypen'], classification_hash['ancestors'].pluck('name').sort)

                # language
                assert_equal('de', json_data['inLanguage'])

                # content data
                assert_equal(@content.name, json_data['headline'])
                assert_equal(@content.description, json_data['description'])
                assert_equal(@content.url, json_data['sameAs'])
                assert_equal(@content.content_url, json_data['contentUrl'])
                assert_equal(@content.content_size, json_data['contentSize'])
                assert_equal(@content.file_format, json_data['fileFormat'])
                assert_equal("PT#{@content.duration}S", json_data['duration'])
              end

              test 'stored item can be found via different endpoints' do
                get(api_v2_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].first
                assert_equal(@content.id, json_data['identifier'])

                get(api_v2_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].first
                assert_equal(@content.id, json_data['identifier'])

                get(api_v2_creative_works_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].first
                assert_equal(@content.id, json_data['identifier'])
              end
            end
          end
        end
      end
    end
  end
end
