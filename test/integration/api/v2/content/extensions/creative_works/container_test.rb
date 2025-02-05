# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V2
      module Content
        module Extensions
          module CreativeWorks
            class Container < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('container')

                @article = DataCycleCore::DummyDataHelper.create_data('article')
                @article.is_part_of = @content.id
                @article.save!
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored container exists' do
                get api_v2_thing_path(id: @article)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                article_json_data = response.parsed_body

                get api_v2_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body

                # validate header
                assert_equal('http://schema.org', json_data['@context'])
                assert_equal('CreativeWork', json_data['@type'])
                assert_equal('Container', json_data['contentType'])
                assert_equal(root_url[0...-1] + api_v2_thing_path(id: @content), json_data['@id'])
                assert_equal(@content.id, json_data['identifier'])
                assert_equal(@content.created_at.as_json, json_data['dateCreated'])
                assert_equal(@content.updated_at.as_json, json_data['dateModified'])
                assert_equal(root_url[0...-1] + thing_path(@content), json_data['url'])

                # classifications
                # TODO: (move to generic tests)
                assert(json_data['classifications'].present?)
                assert_equal(1, json_data['classifications'].size)
                classification_hash = json_data['classifications'].first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Container', classification_hash['name'])
                assert_equal(1, classification_hash['ancestors'].size)
                assert_equal(['Inhaltstypen'], classification_hash['ancestors'].pluck('name').sort)

                # language
                assert_equal('de', json_data['inLanguage'])

                # content data
                assert_equal(@content.name, json_data['headline'])
                assert_equal(@content.description, json_data['description'])

                assert_equal(article_json_data.except('isPartOf'), json_data['hasPart'].first)
                assert_equal(article_json_data['isPartOf'], json_data.except('hasPart'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v2_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].detect { |item| item['contentType'] == 'Container' }
                assert_equal(@content.id, json_data['identifier'])

                get(api_v2_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].detect { |item| item['contentType'] == 'Container' }
                assert_equal(@content.id, json_data['identifier'])

                get(api_v2_creative_works_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = response.parsed_body['data'].detect { |item| item['contentType'] == 'Container' }
                assert_equal(@content.id, json_data['identifier'])
              end
            end
          end
        end
      end
    end
  end
end
