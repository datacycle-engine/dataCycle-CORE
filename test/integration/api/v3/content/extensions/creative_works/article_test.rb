# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module CreativeWorks
            class Article < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.where(template: false).delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('article')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored article exists' do
                get api_v3_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body)

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('Article', json_data.dig('@type').last)
                assert_equal('Artikel', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v3_thing_path(id: @content), json_data.dig('@id'))
                assert_equal(@content.id, json_data.dig('identifier'))
                assert_equal(@content.created_at.as_json, json_data.dig('dateCreated'))
                assert_equal(@content.updated_at.as_json, json_data.dig('dateModified'))
                assert_equal(root_url[0...-1] + thing_path(@content), json_data.dig('url'))

                # validity period
                # TODO: (move to generic tests)
                assert_equal(@content.validity_period.valid_from.to_date.as_json, json_data.dig('datePublished'))
                assert_equal(@content.validity_period.valid_until.to_date.as_json, json_data.dig('expires'))

                # classifications
                # TODO: (move to generic tests)
                assert(json_data.dig('classifications').present?)
                assert_equal(1, json_data.dig('classifications').size)
                classification_hash = json_data.dig('classifications').first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Artikel', classification_hash.dig('name'))
                assert_equal(2, classification_hash.dig('ancestors').size)
                assert_equal(['Inhaltstypen', 'Text'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

                # language
                assert_equal('de', json_data.dig('inLanguage'))

                # content data
                assert_equal(@content.name, json_data.dig('headline'))
                assert_equal(@content.description, json_data.dig('description'))
                assert_equal(@content.text, json_data.dig('text'))
                assert_equal(@content.alternative_headline, json_data.dig('alternativeHeadline'))
                assert_equal(@content.link_name, json_data.dig('name'))
                assert_equal(@content.url, json_data.dig('sameAs'))

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data.dig('image').first.dig('identifier'))
                assert_equal(@content.author.first.id, json_data.dig('author').first.dig('identifier'))
                assert_equal(@content.about.first.id, json_data.dig('about').first.dig('identifier'))
                assert_equal(@content.content_location.first.id, json_data.dig('contentLocation').first.dig('identifier'))

                # check for tag classification and keyword transformation
                # TODO: (move to Transformations tests)
                # API: Transformation: Classification.keywords
                assert_equal(@content.tags.first.name, json_data.dig('tags').first.dig('name'))
                assert_equal(@content.tags.first.name, json_data.dig('keywords'))
                assert_equal(@content.keywords, json_data.dig('keywords'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| Array.wrap(item.dig('@type')).last == 'Article' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| Array.wrap(item.dig('@type')).last == 'Article' }
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_creative_works_path)
                assert_response(:success)
                assert_equal('application/json; charset=utf-8', response.content_type)
                json_data = JSON.parse(response.body).dig('data').detect { |item| Array.wrap(item.dig('@type')).last == 'Article' }
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

                excepted_params = ['@id', 'author', 'about', 'image', 'contentLocation', 'tags']

                assert_equal(api_v3_json.except(*excepted_params), api_v2_json.except(*excepted_params))
                assert_equal(api_v3_json.dig('author').first.except(*excepted_params), api_v2_json.dig('author').first.except(*excepted_params))
                assert_equal(api_v3_json.dig('about').first.except(*excepted_params), api_v2_json.dig('about').first.except(*excepted_params))
                assert_equal(api_v3_json.dig('image').first.except(*excepted_params), api_v2_json.dig('image').first.except(*excepted_params))
                assert_equal(api_v3_json.dig('tags').first.except('uri'), api_v2_json.dig('tags').first)
                assert_equal(api_v3_json.dig('contentLocation').first.except(*excepted_params), api_v2_json.dig('contentLocation').first.except(*excepted_params))
              end
            end
          end
        end
      end
    end
  end
end
