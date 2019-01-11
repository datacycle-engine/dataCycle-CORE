# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      class ThingTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'json of stored article exists' do
          get api_v3_thing_path(@content)

          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data = JSON.parse(response.body)
          assert_equal('TestArtikel', json_data['headline'])
        end

        test 'stored article can be found and is correct' do
          get(api_v3_things_path)

          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data = JSON.parse(response.body)

          assert(json_data.dig('data').present?)
          assert_equal(1, json_data.dig('data').size)

          data_hash = json_data.dig('data').first
          assert_equal('http://schema.org', data_hash.dig('@context'))
          assert_equal('CreativeWork', data_hash.dig('@type'))
          assert_equal('Artikel', data_hash.dig('contentType'))
          assert(data_hash.dig('@id').present?)
          assert_equal(@content.id, data_hash.dig('identifier'))
          assert(data_hash.dig('url').present?)
          assert(data_hash.dig('dateCreated').present?)
          assert(data_hash.dig('dateModified').present?)
          assert_equal('de', data_hash.dig('inLanguage'))
          assert_equal('TestArtikel', data_hash.dig('headline'))

          assert(data_hash.dig('classifications').present?)
          assert_equal(1, data_hash.dig('classifications').size)
          classification_hash = data_hash.dig('classifications').first
          assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
          assert_equal('Artikel', classification_hash.dig('name'))
          assert_equal(2, classification_hash.dig('ancestors').size)
          assert_equal(['Inhaltstypen', 'Text'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

          assert(json_data['meta'].present?)
          assert_equal(1, json_data.dig('meta', 'total'))
          assert_equal(1, json_data.dig('meta', 'pages'))
          assert(json_data['links'].present?)
          assert(json_data.dig('links', 'self').present?)
        end

        test 'stored article can be found in different ways' do
          get(api_v3_contents_search_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_search = JSON.parse(response.body)

          get(api_v3_things_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_things = JSON.parse(response.body)

          get(api_v3_creative_works_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_creative_works = JSON.parse(response.body)

          assert(json_data_search != json_data_things)
          assert_equal(json_data_search.except('links'), json_data_things.except('links'))
          assert(json_data_search != json_data_creative_works)
          assert_equal(json_data_search.except('links'), json_data_creative_works.except('links'))
        end

        test 'sorted article is also found in V2 and has the same values as V3' do
          get(api_v2_contents_search_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_search_old = JSON.parse(response.body)
          data_hash_old = json_data_search_old['data'].first

          get(api_v3_contents_search_path)
          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data_search = JSON.parse(response.body)
          data_hash = json_data_search['data'].first

          assert_equal(data_hash.except('@id'), data_hash_old.except('@id'))
          assert_equal(1, json_data_search.dig('meta', 'total'))
          assert_equal(json_data_search_old.dig('meta', 'total'), json_data_search.dig('meta', 'total'))
        end
      end
    end
  end
end
